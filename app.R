#
sentimentTime <- readRDS("data/sentimentTime.rds")
#
library(shiny)
library(plotly)
# Define UI for application that draws a histogram
ui <- fluidPage(
   # Application title
   titlePanel("Sentiment changes as the discussion progresses in the answers of a thread"),
   sidebarLayout(
      sidebarPanel(
        # Select variable for x-axis
         sliderInput(inputId = "x",
                     label = "Sequence of Posts", 
                     min = min(sentimentTime$Sequence), max = max(sentimentTime$Sequence), 
                     value = c(0, 15)),
         # Select variable for y-axis
         selectInput(inputId = "y", 
                     label = "Sentiment Lexicon",
                     choices = levels(sentimentTime$SentimentLexicon), 
                     selected = levels(sentimentTime$SentimentLexicon)[1]),
         
         # Select variable for sentiment of the questions
         selectInput(inputId = "Questions", 
                     label = "Sentiment of questions",
                     choices = c("All posts",levels(subset(sentimentTime, Sequence == 0)$Polarity)), 
                     selected = "All posts"),
        # Select variable for time range
          sliderInput(inputId = 'CreationDate', 
                      label = 'Time range', 
                      min = min(sentimentTime$CreationDate), max = max(sentimentTime$CreationDate), 
                      value = c(min(sentimentTime$CreationDate),max(sentimentTime$CreationDate)))

         ),
      # Show a plot of the generated distribution
      mainPanel(
         plotlyOutput("plot")
      )
   ))


# Define server logic required to draw line graph
sentimentTime <- sentimentTime%>% 
  group_by(SentimentLexicon, Id) %>% 
  arrange(Id, Sequence)
server <- function(input, output) {
  dataInput <- reactive({
    data <- subset(sentimentTime, Sequence >= input$x[1] & 
                     Sequence <= input$x[2] & 
                     SentimentLexicon %in% input$y &
                     CreationDate >= input$CreationDate[1] &
                     CreationDate <= input$CreationDate[2])

    
    if(input$Questions=='negative'){
      data <- filter(data, first(Sentiment) < 0)
    }else if(input$Questions=='positive'){
      data <- filter(data, first(Sentiment) > 0)
    }else if (input$Questions=='neutral'){
      data <- filter(data, first(Sentiment) == 0)
    }
    
    data <- ungroup(data)
  })
  output$plot <- renderPlotly({
    ggplotly({
      data <- dataInput()
    
    ggplot(data, aes(Sequence, Sentiment, color = Polarity)) +
      geom_line(aes(group = Id),show.legend = F, alpha = 1/10)+
      stat_summary(fun.y=mean, geom="line", aes(colour="mean"))+
      scale_colour_manual(values=c("mean"="gray", "negative"="coral", "positive"="cyan", "neutral" = "green")) + 
      labs(colour="")
            })
  })
}

# Run the application 
shinyApp(ui = ui, server = server)