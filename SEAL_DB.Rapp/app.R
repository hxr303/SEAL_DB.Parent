# install.packages(c("shiny", "shinydashboard", "DT", "sodium", "RPostgreSQL", "DBI", "shinyjs", "shinyauthr", "here"))

library(shiny)
library(shinydashboard)
library(DT)
library(shinyjs)
library(sodium)
library(shinyauthr)

rm(list=ls())


setwd("/Users/emericmellet/Desktop/Local /SEAL_DB.Parent/SEAL_DB.Rapp")

loginpage <- div(id = "loginpage", style = "width: 500px; max-width: 100%; margin: 0 auto; padding: 20px;",
                 wellPanel(
                    tags$h2("LOG IN", class = "text-center",
                            style = "padding-top: 0;color:#333; font-weight:600;"),
                    img(src = "https://github.com/hxr303/S.E.A.L.-Database/blob/main/FlogoBN.jpg?raw=true",
                        width = "200px", height = "160px",
                        style = "display: block; margin: 0 auto;"),
                    textInput("userName", placeholder="Username",
                              label = tagList(icon("user"),
                                              "Username")),
                    passwordInput("passwd",
                                  placeholder="Password",
                                  label = tagList(icon("unlock-alt"),
                                                  "Password")),
                    br(),
                    div(
                       style = "text-align: center;",
                       actionButton("login", "SIGN IN",
                                    style = "color: white; background-color:#3c8dbc;
                                 padding: 10px 15px; width: 150px; cursor: pointer;
                                 font-size: 18px; font-weight: 600;"),
                       shinyjs::hidden(
                          div(id = "nomatch",
                              tags$p("Incorrect username or password!",
                                     style = "color: red; font-weight: 600; 
                                            padding-top: 5px;font-size:16px;", 
                                     class = "text-center"))),
                       br(),
                       br(),
                       tags$code("Username: Admin  Password: pass"),
                       br(),
                       tags$code("Username: Viewer  Password: sightseeing"),
                       br(),
                       tags$code("Username: Guest (Create account, not available now)  Password: 123")
                       
                    ))
)

credentials = data.frame(
   username_id = c("Admin", "Viewer", "Guest"),
   passod   = sapply(c("pass", "sightseeing", "123"), password_store),
   permission  = c("advanced", "basic", "none"), 
   stringsAsFactors = FALSE
)

header <- dashboardHeader( title = "S.E.A.L Database",
                           tags$li(
                              class = "dropdown",
                              style = "padding: 8px;",
                              shinyauthr::logoutUI("logout")
                           ),
                           tags$li(
                              class = "dropdown",
                              tags$a(
                                 icon("github"),
                                 href = "https://github.com/SlippyRicky/PaleoIchonoDBSearch_R.git",
                                 title = "Find the code on github"
                              )
                           )
)



sidebar <- dashboardSidebar(uiOutput("sidebarpanel"),
                            collapsed = TRUE
)

body <- dashboardBody(shinyjs::useShinyjs(),
                      uiOutput("body")
)

ui <- dashboardPage(header,
                    sidebar,
                    body,
                    skin = "blue",
                    tags$head(
                       tags$style(
                          HTML("code {color: #008080; /* Teal color */}")
                       )
                    )
)


server <- function(input, output, session) {
   
   login = FALSE
   
   USER <- reactiveValues(login = login)
   
   observe({
      if (USER$login == FALSE) {
         if (!is.null(input$login)) {
            if (input$login > 0) {
               Username <- isolate(input$userName)
               Password <- isolate(input$passwd)
               
               matching_indices <- which(credentials$username_id == Username)
               
               if (length(matching_indices) == 1) {
                  pasmatch <- credentials[matching_indices, "passod"]
                  pasverify <- password_verify(pasmatch, Password)
                  
                  if (pasverify) {
                     USER$login <- TRUE
                  } else {
                     shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade")
                     shinyjs::delay(3000, shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade"))
                  }
               } else {
                  shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade")
                  shinyjs::delay(3000, shinyjs::toggle(id = "nomatch", anim = TRUE, time = 1, animType = "fade"))
               }
            }
         }
      }
   })
   
   output$logoutbtn <- renderUI({
      req(USER$login)
      tags$li(a(icon("fa fa-sign-out"), "Logout", 
                href="javascript:window.location.reload(true)"),
              class = "dropdown", 
              style = "background-color: #eee !important; border: 0;
                    font-weight: bold; margin:5px; padding: 10px;")
   })
   
   
   output$sidebarpanel <- renderUI({
      if (USER$login == TRUE) {
         
         user_permission <- credentials[credentials$username_id == isolate(input$userName), "permission"]
         
         menuItems <- list()
         
         if (user_permission %in% c("none")) {
            menuItems<- list( menuItems,
                              list(menuItem("Create account", tabName = "create_account", icon = icon("user"))
                              )
            )
         }
         
         if (user_permission %in% c("basic")) {
            menuItems <- list( menuItems,
                               list(menuItem("Welcome", tabName = "welcome_tab", icon = icon("home"))),
                               list(menuItem("Search", tabName = "search_db", icon = icon("search"))),
                               list(menuItem("About", tabName = "about", icon = icon("info-circle")))
            )
         }
         
         if (user_permission %in% c("advanced")) {
            menuItems <- list( menuItems,
                               list(menuItem("Welcome", tabName = "welcome_tab", icon = icon("home"))),
                               list(menuItem("Search", tabName = "search_tab", icon = icon("search"))),
                               list(menuItem("Download", tabName = "download_tab", icon = icon("download"))),
                               list(menuItem("Update", tabName = "update_tab", icon = icon("exchange-alt"))),
                               list(menuItem("Create Account", tabName = "create_account", icon = icon("user")))
            )
         }
         sidebarMenu(menuItems)
      }
   })
   
   
   output$body <- renderUI( {
      if (USER$login == TRUE) {
         tabItems(
            tabItem(tabName = "welcome_tab",
                    titlePanel("Welcome to S.E.A.L."),
                    fluidPage(
                       p("Welcome to the S.E.A.L. Database – a scientific gateway
                    to explore and manage comprehensive information about seal
                    anatomy. The steps listed below outline the initial steps
                    of setting up your own database so that it may provide an
                    understanding of seals and their anatomical nuances.",
                         
                         p("1) The first step is to start building all the tables
                    required for managing the database. Use the SQL query ",
                           code("all_tables.sql"), ". The query consists of five tables:"),
                         
                         br(),
                         "a. Data_tags -- These tables are still incomplete",
                         br(),
                         "b. Data_reference",
                         br(),
                         "c. Data_uncertainty",
                         br(),
                         "d. User_data",
                         br(),
                         "e. User_documentation",
                         br(),
                         "f. Now import the file ",
                         code("data_tags.csv"), " into the ", code("data_tags"),
                         " table, and ",
                         code("link_path"), " into the ", code("data_reference"),
                         " table in the ", code("link_path"), " column",
                         br(),
                         "g. Important note: use the query ", code("remove_rows.sql"),
                         " to delete the rows [125, 126, 127]"
                       ),
                       
                       p("2) After having installed the tables and alterations have
                    been made, now is the time to fill picture_number in",
                         code("data_tags") ,",", code("data_reference"), ", and",
                         code("data_uncertainty"), ". Using the queries and functions."
                       ),
                       
                       "a. First, fill the ", code("picture_number"), " column in ",
                       code("data_tags"), " using the ", code("picture_number_column_generator.sql"),
                       " query. This will use the function ",
                       code("generate_unique_random_number().sql"),
                       br(),
                       "b. Then use the queries to transfer the columns from ",
                       code("data_tags"), " to ", code("data_reference"),
                       " and ", code("data_uncertainty"),
                       br(),
                       "   i. To transfer from ",
                       code("data_tags"), " to ", code("data_reference"), ": ",
                       code("picture_number_from_data_tags_to_data_reference.sql"),
                       br(),
                       "   ii. To transfer from ",
                       code("data_tags"), " to ", code("data_uncertainty"), ": ",
                       code("picture_number_from_data_tags_to_data_uncertainty.sql"),
                       br(),
                       "c. Use the query ",
                       code("insert_scrape_name.sql")," to fill in the column ",
                       code("scrape_name")," in ", code("data_tags"),
                       br(),
                       "d. Use the query ", code("store_image_as_binary_file.sql"),
                       " to fill in the ", code("stored_image"), " column in ", 
                       code("data_reference"),
                       
                       p("3) After having altered the tables and each one contains the
                  necessary information about the seals, it is now time to focus
                  on the functions that allow for the automated scalability of
                  the database."),
                       
                       h3("Image Viewer"),
                       p("This database currently contains bone images from six 
                    species distributed across three families within the suborder 
                    Pinnipedia. The families present are Phocidae (fur seals and
                    sea lions), Odobenidae (walruses) and Phocidae (fur seals)
                    [1], [2]."),
                    ),
                    
                    fluidRow(
                       selectInput("image", "Select an Image:",
                                   choices = c("Overview", "Atlas", "Baculum", "Brain Endocast", "Femur", 
                                               "Complete Forelimb", "Humerus", "Lower Jaw", "Mandible", "Pelvis",
                                               "Phalanges", "Radius", "Rib", "Scapula", "Skull", 
                                               "Tibia and Fibula", "Ulna", "Cervical Vertebrae", 
                                               "Lumbar Vertebrae", "Thoracical Vertebrae"),
                                   selected = "Overview"
                       ),
                       imageOutput("selectedImage")
                    )
            ),
            
            tabItem(tabName = "search_tab",
                    fluidRow(
                       box(
                          title = "Search",
                          status = "primary",
                          solidHeader = TRUE,
                          width = 12,
                          textInput("search_input", label = "Enter search words", value = ""),
                          actionButton("search_button", "Search")
                       )
                    ),
                    fluidRow(
                       box(
                          title = "Results",
                          width = 12,
                          DTOutput("search_result"),
                          textOutput("error")
                       )
                    )
            ),
            
            tabItem(tabName = "download_tab",
                    fluidPage(
                       titlePanel("Download Data"),
                       p("This section allows you to download data from the database. Customize this UI as needed."),
                       fluidRow(
                          box(
                             title = "Select Download Options",
                             status = "primary",
                             solidHeader = TRUE,
                             width = 12,
                             textInput("search_input", label = "Enter search key",
                                       value = "", placeholder = " your search key "),
                             selectInput("download_option", "Select Download Option",
                                         choices = c("Server 1", "")),
                             downloadButton("download_data_btn", "Download Data")
                          )
                       )
                    )
            ),
            
            tabItem(tabName = "update_tab",
                    fluidPage(
                       titlePanel("Update Data"),
                       p("This section allows you to update data in the database.
                    Customize this UI as needed."),
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
            ),
            
            tabItem(tabName = "create_account",
                    h2("Create Account"),
                    textInput("new_username", "Username"),
                    passwordInput("new_password", "Password",
                                  placeholder = "Beware of the password you use"),
                    passwordInput("confirm_password", "Confirm Password"),
                    textInput("additional_comments", "Additional Comments",
                              placeholder = "Please write name and student ID
                        if applicable"),
                    actionButton("create_account_btn", "Create Account")
            )
         )
      }
      else {
         loginpage
      }
   })
}


shinyApp(ui = ui, server = server)

