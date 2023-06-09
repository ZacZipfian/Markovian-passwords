module App
using GenieFramework, StippleLatex, Random, LinearAlgebra, StableRNGs, QuantEcon, Statistics, Distributions, FileIO, ImageIO, ImageCore

@genietools

Genie.config.cors_headers["Access-Control-Allow-Origin"]  =  "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

const FILE_PATH = "upload"
mkpath(FILE_PATH)


#Initialise functions
function indexMe(char_set, CharInt)
    for i in 1:75
        if getindex(char_set,i) == CharInt
            return i
        end      
    end  
end

function TransMatxx(Markov)
    n = size(Markov,1);
    trans = zeros(n,n);
    for i = 1:n
       trans[i,:] = (Markov[i,:]*(1/sum(Markov[i,:])))    
    end
    return trans
end

function mc_path(P, char_set; seed, init , sample_size)
    if  seed >= 18446744073709551616 && seed <= (3/2)*18446744073709551615
      rng = StableRNG( round(UInt128, 2*(seed/3)))
      rng2 = StableRNG( round(UInt128,(seed/3)))
    elseif seed > (3/2)*18446744073709551615
      rng = StableRNG( round(UInt128, log(seed)))
      rng2 = StableRNG(round(UInt128, log((seed-1000)/2)))
    else
      rng = StableRNG(seed)
    end
    @assert size(P)[1] == size(P)[2] # square required
    N = size(P)[1] # should be square

    # create vector of discrete RVs for each row
    dists = [Categorical(P[i, :]) for i in 1:N]

    # setup the simulation
    X = fill(0, sample_size) # allocate memory, or zeros(Int64, sample_size)
    X[1] = init # set the initial state
    Random_text = string(char_set[init])

    for t in 2:sample_size
        dist = dists[X[t-1]] # get discrete RV from last state's transition distribution
        X[t] = rand(rng, dist) # draw new value
        Random_text = string(Random_text,"",char_set[X[t]])
    end
    return Random_text
end


function password_generator_mc(SeedNumb, FILE_PATH, Document_name, Checker::Int, Image_name, Length::Int64, isdocx::Int)
   # Prompt user to input a number
   rng2 = 0;
  # SeedNumb = parse(UInt128, readline())

   if  SeedNumb >= 18446744073709551616 && SeedNumb <= (3/2)*18446744073709551615
      rng = StableRNG( round(UInt128, 2*(SeedNumb/3)))
      rng2 = StableRNG( round(UInt128,(SeedNumb/3)))
   elseif SeedNumb > (3/2)*18446744073709551615
       rng = StableRNG( round(UInt128, log(SeedNumb)))
       rng2 = StableRNG(round(UInt128, log((SeedNumb-1000)/2)))
   else
       rng = StableRNG(SeedNumb)
   end


   # Read text document into a string
   if isdocx == 1
    
   else
    DocuString = read(joinpath(FILE_PATH, Document_name), String)
   end

   #Is an image added
   if Checker == 1
      img = FileIO.load(joinpath(FILE_PATH, Image_name))
      imgarr = channelview(img)
      SeedNumb2 =  round(Int128, (mean(imgarr)*100_000_000_000) + (median(imgarr)*100_000_000_000))
      if rng2 == 0
         rng2 = StableRNG(SeedNumb2)
      else
        SeedNumb2 = SeedNumb2 + round(UInt128, log10(SeedNumb/3)) 
        rng2 = StableRNG(SeedNumb2)
      end
   end

   # Remove non-alphanumeric characters
   DocuString = replace(DocuString, r"[^A-Za-z0-9!@#$%&?*^+-=_]" => " ")
   DocuString = replace(DocuString, r"\s+" => "")


   char_set = ['A':'Z'; 'a':'z'; '0':'9'; '!'; '@'; '#'; '$'; '%'; '&'; '?'; '*'; '^'; '+'; '-'; '='; '_']

   # Create Markov chain
   N = length(DocuString)
   CPrevious = DocuString[1]
   markov_chain = zeros(Float64, 75, 75)

   for i in 2:N
       if rand(rng) < 1/2^log2(N)
          CurrentC = DocuString[i]
       else
           if rng2 == 0
              CurrentC = rand(rng, char_set)
           else
              CurrentC = rand(rng2, char_set)
           end
       end
       markov_chain[indexMe(char_set, CPrevious), indexMe(char_set, CurrentC)] += 1
       CPrevious = CurrentC
   end

   # Create transition matrix from the Markov chain
   transition_matrix = TransMatxx(markov_chain)

   # Generate pseudo-random string of length M using transition matrix
   M = Length
   rand_string = mc_path(transition_matrix, char_set, seed=SeedNumb, init=rand(rng,1:75), sample_size = M)

   return(rand_string)
end

function new_or_old(upfiles, name_o_file) 
    for i in 1:(size(upfiles,1))
        if upfiles[i] == name_o_file
             global casek = i
        end
    end
    if casek == 1
      indxfnder = [2,3]
    elseif casek == 2
      indxfnder = [1,3]
    elseif casek == 3
      indxfnder = [1,2]
    end
    return indxfnder
end




##############
 route("/", method = POST) do
     files = Genie.Requests.filespayload()
     for f in files
         write(joinpath(FILE_PATH, f[2].name), f[2].data)
         ###
         global name_o_file = f[2].name
     end
     if length(files) == 0
         @info "No file uploaded" 
     end
        
        upfiles = readdir(FILE_PATH)
        if size(upfiles,1) == 1 
            
        elseif  size(upfiles,1) == 2 
              name_1 = upfiles[1]
              name_2 = upfiles[2]
              length_1 = length(name_1)
              length_2 = length(name_2)
              type_1 = SubString(name_1, (length_1-3), length_1)
              type_2 = SubString(name_2, (length_2-3), length_2)
              if (type_1 == type_2) || (type_1 == ".png" && type_2 == ".jpg") || (type_2 == ".png" && type_1 == ".jpg")
                  indxfnder = new_or_old(upfiles, name_o_file)
                  rm(joinpath(FILE_PATH, upfiles[indxfnder[1]]))
              end
        elseif  size(upfiles,1) == 3 
              name_1 = upfiles[1]
              name_2 = upfiles[2]
              name_3 = upfiles[3]
              length_1 = length(name_1)
              length_2 = length(name_2)
              length_3 = length(name_3)
              type_1 = SubString(name_1, (length_1-3), length_1)
              type_2 = SubString(name_2, (length_2-3), length_2)
              type_3 = SubString(name_3, (length_3-3), length_3)
              if (type_1 == type_2) || (type_1 == ".png" && type_2 == ".jpg") || (type_2 == ".png" && type_1 == ".jpg")
                  indxfnder = new_or_old(upfiles, name_o_file)
                  rm(joinpath(FILE_PATH, upfiles[indxfnder[1]]))
              end
              if (type_2 == type_3) || (type_2 == ".png" && type_3 == ".jpg") || (type_3 == ".png" && type_2 == ".jpg")
                indxfnder = new_or_old(upfiles, name_o_file)
                rm(joinpath(FILE_PATH, upfiles[indxfnder[2]]))
              end
              if (type_1 == type_3) || (type_1 == ".png" && type_3 == ".jpg") || (type_3 == ".png" && type_1 == ".jpg")
                indxfnder = new_or_old(upfiles, name_o_file)
                k = indxfnder[1]
                if k == 1
                   rm(joinpath(FILE_PATH, upfiles[indxfnder[1]]))
                else
                   rm(joinpath(FILE_PATH, upfiles[indxfnder[2]]))
                end
              end
           end
    
     
     return "Upload finished"
   end


@handlers begin
    @in M_length_num = 30
    @in Seed_Number = 10
    @out Display_text = ""
    @in selected_image = "a"
    @in start = false
    @private running = false
    ###
    @in selected_file = "a"
    ###
    @in clear = false
    @onchange start begin
        upfiles = readdir(FILE_PATH)
        if (size(upfiles,1)) == 0

        else
           checker = 0
           isdocx = 0
           for i in 1:(size(upfiles,1))
              find_type = upfiles[i]
              find_type_length = length(find_type)
              sort_out = SubString(find_type, (find_type_length-3), find_type_length)
             if sort_out == ".txt"
                selected_file = find_type
             elseif sort_out == "docx"
                isdocx = 1
                selected_file = find_type
             elseif sort_out == ".png" || sort_out == ".jpg"
                selected_image = find_type
                checker = 1
             end
           end
           if selected_file == "a"

           else
              Display_text = password_generator_mc(Seed_Number, FILE_PATH, selected_file, checker, selected_image, M_length_num, isdocx)
           end
       end
    end
    
    @onchange clear begin
        M_length_num = 30 
        Seed_Number = 10
        Display_text = ""
        if selected_file == "a"

        else
           rm(joinpath(FILE_PATH, selected_file))
           selected_file = "a"
        end

        if selected_image == "a"

        else 
           rm(joinpath(FILE_PATH, selected_image))
           selected_image = "a"
        end
    end
end


@page("/", "app.jl.html")
Server.isrunning() || Server.up()
end
