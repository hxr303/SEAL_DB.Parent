library(shinyjs)
library(shiny)
library(shinydashboard)
library(DT)
library(DBI)
library(RPostgreSQL)

rm(list=ls())
setwd("/")

# Define the server address 
con <- dbConnect(
  PostgreSQL(),
  dbname = "TEST1",           #name of imported database
  port = 5432,                   #port of imported server
  user = "postgres",             #username
  password = "password")         #password


# UI sections defined
## Welcome UI
welcome_tab_ui <- shinydashboard::tabItem(
  tabName = "welcome",
  fluidPage(
    titlePanel("Image Viewer"),
    p("This database currently contains bone images from six species distributed
      across three families within the suborder Pinnipedia. The families present
      are Phocidae (fur seals and sea lions), Odobenidae (walruses), and
      Otariidae (eared seals) [1], [2].")
  )
)

## Search UI
search_tab_ui <- shinydashboard::tabItem(
  
  fluidRow(
    box(
      title = "Search",
      status = "primary",
      solidHeader = TRUE,
      width = 12,
      textInput("search_input", label = "Enter search words", value = ""),
      actionButton("search_button", "Search")
    ),
    
    fluidRow(
      box(
        title = "Search Results",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        DTOutput("search_result"),
        textOutput("error")
      )
    )
  )
)

## Update UI
update_tab_ui <- shinydashboard::tabItem(
  tabName = "update_tab",
  fluidPage(
    titlePanel("Update Data"),
    p("This section allows you to update data in the database. Customize this UI as needed."),
    fluidRow(
      box(
        title = "Update Table",
        status = "primary",
        solidHeader = TRUE,
        width = 12,
        DTOutput("update_table")
      )
    )
  )
)

# UI function for the dashboard
dashboard_ui <- shinydashboard::dashboardPage(
  skin = "purple",
  dashboardHeader(title = "S.E.A.L."),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Welcome", tabName = "welcome_tab", icon = icon("home")),
      menuItem("Search", tabName = "search_tab", icon = icon("search")),
      menuItem("Downloads", tabName = "update_tab_ui", icon = icon("download")), 
      menuItem("Update", tabName = "edit_values", icon = icon("edit")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "welcome_tab", welcome_tab_ui),
      tabItem(tabName = "search_tab", search_tab_ui),
      tabItem(tabName = "dowload_tab"),
      tabItem(tabName = "update_table"),
      tabItem(tabName = "about_tab")
    )
  ),
)

# Define server logic
server <- function(input, output, session) {
  
  # Read data from the "data_tags.csv" file
  initial.query <- "SELECT * FROM data_tags"
  data1 <- dbGetQuery(con, initial.query)
  data2 <- dbGetQuery(con, initial.query)
  
  updates <- reactiveVal(NULL)
  
  ## Retrieve images from given file name
  output$selectedImage <- renderImage({
    
    ## Define the images' source directory
    img_dir <- "www/"
    
    ## Concatenate the image file path
    img_path <- file.path(img_dir, paste0(input$image, ".png"))
    
    ## Compose image formatting details 
    list(src = img_path, 
         alt = "Selected Image",
         width = "100%")}, 
    deleteFile = FALSE)
  
  ## Updates the contents of the drop-down menu for Seal images 
  observe({
    updateSelectInput(session, "image", choices = slidenames.vector)
  })
  
  ## Render data table function
  output$table_view <- shiny::renderDataTable({data1},
                                options = list(scrollX = TRUE, searching = FALSE))
  
  ## React to pressing search button
  observeEvent(input$search_button, {
    search_words <- tolower(strsplit(input$search_input, " ")[[1]])
    
    if (length(search_words) > 0) {
      filtered_data <- data()[apply(data(), 1, 
                                    function(row) {
                                      all(sapply(search_words, function(word) any(grepl(paste0("\\b", word, "\\b"), tolower(row), ignore.case = TRUE))))
                                    }),
      ]
    }
    else {filtered_data <- data()}
    
    output$update_table <- renderDT({filtered_data},
                                    options = list(scrollX = TRUE, dom = 'Bfrtip', buttons = c('copy', 'csv', 'excel', 'pdf', 'print')))
  }
  )
  
  ## Run the Updates 
  observeEvent(input$update_table_cell_edit, {
    info <- input$update_table_cell_edit
    modified_data <- data()
    
    if (!is.null(info)) {
      cell_row <- info$row
      cell_col <- info$col
      new_value <- info$value
      
      update <- data.frame(
        Row = cell_row,
        Column = colnames(modified_data)[cell_col],
        Old_Value = modified_data[cell_row, cell_col],
        New_Value = new_value
      )
      
      cat("Cell Edited - Row:", cell_row,
          "Column:", cell_col,
          "New Value:", new_value,
          "\n")
      
      # Update the reactive data
      modified_data[cell_row, cell_col] <- new_value
      data(modified_data)
      
      # Update the reactive value with the captured update
      updates(rbind(updates(), update))
    }
  })
  
  ### TESTER CODE FOR THE MAIN app.R ##########################################
  # observe({
  #   updateSelectInput(session, "image", choices = slidenames.vector)
  # })
  # 
  # observe({
  #   print(slidenames.vector)
  #   img_path <- file.path("www/", paste0(input$image, ".png"))
  #   print(img_path)
  #   updateSelectInput(session, "image", choices = slidenames.vector)
  # })
  
  #############################################################################
  
  # Expose updates for About Seal tab
  observeEvent(updates(), {
    updates_data <- updates()
    updateTabsetPanel(session, "mainTabs", "about_seal")
    updateTextAreaInput(session, "updates_text", value = paste0(capture.output(updates_data), collapse = "\n"))
  })
}

# Run the application 
shiny::shinyApp(ui = dashboard_ui, server = server)

