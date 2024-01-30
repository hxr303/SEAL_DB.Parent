#
# This provides database editing examples.
#
# Explore these to learn how you can edit the database.
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
dbDisconnect(con)


###################### Roll back commitment ######################
# Start editing
dbBegin(con)
# Roll back
dbRollback(con)
# Commit
dbCommit(con)
# Disconnect
dbDisconnect(con)


###################### Examples of editing ######################

########### Query the tables
tables <- dbListTables(con)
print(tables)

########### Load the initial table
initial.query <- "SELECT * FROM data_tags;"
initial.table  <- dbGetQuery(con, initial.query)



########### 1. Update data (changes to the table from the dataset)

# Set all rows in "sex" column into "male" from table "data_tags"
query <- "UPDATE data_tags SET sex = 'male';"
dbExecute(con, query)

# Set "sex" column of the "Cystophora cristata" row in "specimen" column to "male"
query <- "UPDATE data_tags
          SET sex = 'female'
          WHERE specimen = 'Cystophora cristata';"
dbExecute(con, query)

# Set a certain cell from table "data_tags" by giving a certain row and column
query <- "UPDATE data_tags
          SET sex = 'female'
          WHERE logic_tag = '1';"
dbExecute(con, query)



########### 2. Insert data (changes to the table from the dataset)

# Insert a new row with "specimen" as "specimen"
query <- "INSERT INTO public.data_tags (\"specimen\") VALUES ('specimen');"
dbExecute(con, query)

# Insert a new column called "size" with the data type of integer
query <- "ALTER TABLE data_tags ADD COLUMN size INTEGER"
dbExecute(con, query)



########### 3. Delete data (changes to the table from the dataset)

# Delete the table "data_tags"
query <- "DELETE FROM data_tags"
dbExecute(con, query)

# Delete "specimen" column from table "data_tags"
query <- "ALTER TABLE data_tags DROP COLUMN specimen"
dbExecute(con, query)


# Delete the "specimen" row in "specimen" column from table "data_tags"
query <- "DELETE FROM data_tags
          WHERE specimen = 'specimen';"
dbExecute(con, query)



########### 4. Create tables (changes to the table from the dataset)

# Create the table named msp, including columns "specimen" and "picture_numbe" with data types "text" and "integer", add more columns as needed
query <- "CREATE TABLE IF NOT EXISTS public.msp (
          specimen text,
          picture_number integer);"
dbExecute(con, query)

# Create the table and set "picture_number" as the primary key
query <- "CREATE TABLE IF NOT EXISTS public.msp (
          specimen text,
          picture_number integer,
          CONSTRAINT picture_number_pkey PRIMARY KEY (picture_number));"
dbExecute(con, query)


########### 5. Order data (changes to the table from the dataset)

# Get ordered table "data_tags" based on "logic_tag" in ascending order
query <- "SELECT * FROM data_tags ORDER BY logic_tag;"
dbExecute(con, query)
# Or
query <- "SELECT * FROM data_tags ORDER BY specimen ASC;"
dbExecute(con, query)

# Get ordered table "data_tags" based on "logic_tag" in descending order
query <- "SELECT * FROM data_tags ORDER BY logic_tag DESC;"
dbExecute(con, query)

# Get ordered table "data_tags" based on "bone" first, then "logic_tag"
query <- "SELECT * FROM data_tags ORDER BY bone,logic_tag;"
dbExecute(con, query)



########### 6. Query the editing history
#!!!!!!!!!!!!




