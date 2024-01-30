#
# This provides query examples.
#
# Explore these to learn how you can retrieve specific datasets from the database.
#


rm(list=ls())


#################### Software Set Up ######################
#install.packages("RPostgreSQL")
library(RPostgreSQL)


###################### Connect Database ######################
con <- dbConnect(
  PostgreSQL(),
  dbname = "S.E.A.L.",           #name of imported database
  port = 5432,                   #port of imported server
  user = "postgres",             #username
  password = "password")         #password

# Test query to check the connection
connection_query <- "SELECT 1"
connection_result <- dbGetQuery(con, connection_query)
if (!is.null(connection_result)) {
  cat("Connection verified. Test query successful.\n")
} else {
  cat("Error: Connection test query failed.\n")
}

# Disconnect
#dbDisconnect(con)


###################### Examples of Query ######################


########### Query the tables existing in the database
tables <- dbListTables(con)
print(tables)

########### Get all information from the table "data_tags"
initial.query <- "SELECT * FROM data_tags"
initial.table <- dbGetQuery(con, initial.query)


########### 1. Select/exclude certain columns and/or rows 

# Get columns "specimen" and "bone" from the table "data_tags"
query <- "SELECT specimen, bone FROM data_tags"
table <- dbGetQuery(con, query)

# Get all rows having "ulna" in column "bone" from the table "data_tags"
query <- "SELECT * FROM public.data_tags WHERE bone = 'ulna'"
table <- dbGetQuery(con, query)

# Get columns "specimen" and "bone" from the table "data_tags", but only with rows having "Arctocephalus pusillus_1" in column "specimen" and "rib" in column "bone".
query <- "SELECT specimen, bone FROM public.data_tags
           WHERE specimen = 'Arctocephalus pusillus_1'
           AND bone = 'rib';"
table <- dbGetQuery(con, query)

# Get all rows containing "ume" in column "bone" from the table "data_tags"
query <- "SELECT *
          FROM data_tags
          WHERE bone like '%ume%';"
table <- dbGetQuery(con, query)

# Get all rows containing "hum" in column "bone", with "hum" as the start
query <- "SELECT *
          FROM data_tags
          WHERE bone like 'hum%';"
table <- dbGetQuery(con, query)

# Get all rows containing "rus" in column "bone", with "rus" as the end
query <- "SELECT *
          FROM data_tags
          WHERE bone like '%rus';"
table <- dbGetQuery(con, query)

# Get all rows not containing "ume" in column "bone" from the table "data_tags"
query <- "SELECT *
          FROM data_tags
          WHERE bone NOT like '%ume%';"
table <- dbGetQuery(con, query)

# Get rows containing “1"，“2” and "3" in column "logic_tag" from the table "data_tags"
query <- "SELECT *
          FROM data_tags
          WHERE logic_tag IN (1, 2, 3);"
table <- dbGetQuery(con, query)

# Get rows not containing “rib"，“humerus” and "scapula" in column "bone" from the table "data_tags"
query <- "SELECT *
          FROM data_tags
          WHERE bone NOT IN ('rib', 'humerus', 'scapula');"
table <- dbGetQuery(con, query)

# Find a certain cell from table "data_tags" by giving a certain row and column
query <- "SELECT bone
          FROM data_tags
          WHERE logic_tag = '19';"
table <- dbGetQuery(con, query)


########### 2. Order data (changes to tables in R only)

# Get ordered table "data_tags" based on "logic_tag" in ascending order
query <- "SELECT * FROM data_tags ORDER BY logic_tag;"
# Or
query <- "SELECT * FROM data_tags ORDER BY specimen ASC;"
table <- dbGetQuery(con, query)

# Get ordered table "data_tags" based on "logic_tag" in descending order
query <- "SELECT * FROM data_tags ORDER BY logic_tag DESC;"
table <- dbGetQuery(con, query)

# Get ordered table "data_tags" based on "bone" first, then "logic_tag"
query <- "SELECT * FROM data_tags ORDER BY bone,logic_tag;"
table <- dbGetQuery(con, query)



########### 3. Group data

# Check all "specimen"s by grouping
query <- "SELECT specimen FROM data_tags GROUP BY specimen;"
table <- dbGetQuery(con, query)

# Check all "specimen"s by grouping, and count each "specimen"
query <- "SELECT specimen, count(1)
          FROM data_tags GROUP BY specimen;"
table <- dbGetQuery(con, query)

# Check all "specimen"s from the table "data_tags", count each "specimen", and find the max/min number in their "logic_tag"
query <- "SELECT specimen, count(1),max(logic_tag),min(logic_tag)
          FROM data_tags GROUP BY specimen;"
table <- dbGetQuery(con, query)

# Limit the max "logic_tag" be smaller than 100
query <- "SELECT specimen, count(1), max(logic_tag), min(logic_tag)
          FROM data_tags
          GROUP BY specimen
          HAVING max(logic_tag) < 100;"
table <- dbGetQuery(con, query)




########### 4. Conditions

# AND: both conditions are true
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          AND bone = 'rib';"
table <- dbGetQuery(con, query)

# OR: any condition should be true
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          OR bone = 'humerus';"
table <- dbGetQuery(con, query)

# AND & OR:  in this case, either both specimen = 'Arctocephalus pusillus_1' is true, or both bone = 'humerus' and sex = 'female' are true
query <- "SELECT * FROM data_tags
          WHERE specimen = 'Arctocephalus pusillus_1'
          OR bone = 'humerus'
          AND sex = 'female';"
table <- dbGetQuery(con, query)

# IS NOT NULL: select rows that is not null in column "logic_tag" from the table "data_tags"
query <- 'SELECT * FROM data_tags
          WHERE "logic_tag" IS NOT NULL;'
table <- dbGetQuery(con, query)

# BETWEEN: select rows that is between 1 and 10 in column "logic_tag" from the table "data_tags"
query <- "SELECT * FROM data_tags
          WHERE logic_tag BETWEEN 1 AND 10
          ORDER BY logic_tag;"
table <- dbGetQuery(con, query)



########### 5. Join relational tables

# Join two tables "data_tags" and "data_uncertainty" together, with the corresponding columns table1."bone" and table2."bone"
query <- "SELECT *
          FROM data_tags 
          INNER JOIN data_uncertainty 
          ON data_tags.\"bone\" = data_uncertainty.\"bone\";"
table <- dbGetQuery(con, query)

# Set "data_tags" and "data_uncertainty" as t1 and t2 in query
query <- "SELECT *
          FROM data_tags AS t1
          INNER JOIN data_uncertainty AS t2
          ON t1.\"bone\" = t2.\"bone\";"
table <- dbGetQuery(con, query)


########### 6. Users

# Create a user



# Query the user documentation
user.query <- "SELECT user_id FROM user_documentation"
user.table <- dbGetQuery(con, user.query)









