using CSV
using StatFiles
using DataFrames
using ReadStat
using Statistics
using GLM

# Line for Julia repl:
# include("C:/Users/Hugo/Desktop/Julia/1-CompetitiveCreativity/1-datasets/comp.jl")

# Importing the Dataset
df = DataFrame(load("C:/Users/Hugo/Desktop/Julia/1-CompetitiveCreativity/1-datasets/dataset_main_dhash.dta"))

# Keeping only some columns
df = df[:, filter(x -> (x in [:contestid,:playerid, :start_date, :end_date, :contest_length, :subdate, :designs, :rated0, :rated1, :rated2, :rated3, :rated4, :rated5, :countrycode, :winner_1, :player_won, :participation, :avgrating_contest, :players, :designs_per_player, :player_experienced, :player_prev_won, :avgrating_player, :submissionid]), names(df))]
# Removing the missing values
df = df[completecases(df), :]
# Renaming some columns
rename!(df, [:contest_length => :c_length, :participation => :spons_part])

# Apply some functions on some columns
# Remove hours minutes and seconds from dates
df[:start_date] = map(string -> chop(string * "a", tail=10), df[:start_date])
df[:end_date] = map(string -> chop(string * "a", tail=10), df[:end_date])
df[:subdate] = map(string -> chop(string * "a", tail=10), df[:subdate])

# Inverse hotEncoding to get one column for the ratings
df[:rated2] = map(integer -> integer * 2, df[:rated2])
df[:rated3] = map(integer -> integer * 3, df[:rated3])
df[:rated4] = map(integer -> integer * 4, df[:rated4])
df[:rated5] = map(integer -> integer * 5, df[:rated5])
df[:rating] = df[:rated1] + df[:rated2] + df[:rated3] + df[:rated4] + df[:rated5]
deletecols!(df, [:rated0, :rated1, :rated2, :rated3, :rated4, :rated5])

# Replace empty string in winner_1 column
for i = 1:size(df)[1]
    if df[i, :winner_1] == ""
        df[i, :winner_1] = "Anon"
    else
        df[i, :winner_1] = df[i, :winner_1]
    end
end

# showall(first(df, 15))
# println("\n")

# for i = 1:size(names(df))[1]
#     jel = names(df)[i]
#     println(jel)
#     dx = by(df, jel, nrow)
#     sort!(dx, [order(:x1)], rev=true)
#     showall(first(dx, 20))
#     dy = unique!(df[:, jel])
#     print("Unique Values: ")
#     println(size(dy))
#     println("__________________________________")
# end

# Export csv for visualization in Microsoft Power BI
# CSV.write("C:/Users/Hugo/Desktop/Julia/1-CompetitiveCreativity/1-datasets/JCleaned.csv",df)

# Preprocessing for Regression_-_-_-_-_-_-_-_-

df = df[:, filter(x -> (x in [:contestid, :c_length, :designs, :countrycode, :avgrating_contest, :players, :spons_part]), names(df))]

# grouping by contest
db = groupby(df, :contestid)

# Creating a DataFrame
dff = DataFrame(contestid = Int64[], c_length = Int64[], designs = Int64[], countrycode = String[], avgrating_contest = Int64[], players = Int64[], spons_part = Int64[])

# Filling the new DataFrame so that it has one row per contest (only 119 rows)
# All the values are the same for a single contest, so I take the one located in the first row
# Except for the country code, in that case, I take the mode
for i = 1:length(db)[1]
    cid = round(db[i][1, :contestid])
    cl = round(db[i][1, :c_length])
    ds = round(db[i][1, :designs])
    avgr = round(db[i][1, :avgrating_contest])
    pl = round(db[i][1, :players])
    spons = round(db[i][1, :spons_part])
    dtemp = by(db[i], :countrycode, nrow)
    cc = dtemp[dtemp[:x1] .== maximum(dtemp[:x1]), :countrycode][1]
    # Adding a row to the new DataFrame
    push!(dff, [cid cl ds cc avgr pl spons])
end

# Encoding county code to get numerical values (as strings)
listcc = unique(dff[:countrycode])
sizeList = size(listcc)[1]
for i = 1:sizeList
    cc = listcc[i]
    for j = 1:nrow(dff)
        if dff[j, :countrycode] == cc
            dff[j, :countrycode] = string(i)
        end
    end
end

# converting strings to integers
dff[:countrycode] = [parse(Int,x) for x in dff[:countrycode]] 

deletecols!(dff, [:contestid])

# fitting the linear model
ols = lm(@formula(designs ~ c_length+avgrating_contest+players+spons_part+countrycode), dff)
println(ols)
# predicting
predictions = round.(predict(ols), digits=0)

target = dff[:designs]
# Calculating the root mean squared error
rmse = sqrt(mean((target - predictions).^2))
println(rmse)
