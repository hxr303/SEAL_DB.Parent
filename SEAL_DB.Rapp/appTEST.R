library(shinyjs)
library(shiny)
library(shinydashboard)
library(DT)
library(DBI)
library(RPostgreSQL)

rm(list=ls())

con <- dbConnect(
  PostgreSQL(),
  dbname = "TEST1",             #name of imported database
  port = 5432,                   #port of imported server
  user = "postgres",             #username
  password = "password")         #password

initial_query <- "SELECT * FROM data_tags"
data <- dbGetQuery(con, initial_query)

head(data)