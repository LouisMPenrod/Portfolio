#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(ggplot2)
library(dplyr)
library(shinyWidgets)

ui <- fluidPage(

    # Application title
    titlePanel(paste0("Phase Determination of ",files[vid])),
    
    br(),
    
    fluidRow(
        column(3,
               plotOutput("linVelPlot")),
        column(3,
               plotOutput("angVelPlot")),
        column(6,
               plotOutput("mapPlot"))
    ),
    
    fluidRow(
        column(12,
                    sliderTextInput("time",
                                    "Time:",
                                    choices = data$time_edit,
                                    selected = max(data$time_edit),
                                    grid = TRUE,
                                    width = '100%'))),
    
    br(),
    br(),
    
    fluidRow(
        column(3, 
               actionButton("ablend" ,"Mark Latency End")),
        column(3,
               textOutput("lend"))),
    
    br(),
    
    fluidRow(
        column(3, 
               actionButton("abp1end" ,"Mark Phase 1 End")),
        column(3,
               textOutput("p1end"))
        
    ),
    
    br(),
    
    fluidRow(
        column(3,
               actionButton("close","Exit", class = "btn-warning")
    ))

)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$linVelPlot <- renderPlot({
            ggplot() +
            geom_point(data = data, aes(x = time_edit, y = linVel), size = 1L, colour = "gray50") +
            geom_point(data = data %>% filter(time_edit >= 0 & time_edit <= input$time),
                       aes(x = time_edit, y = linVel))+
            geom_line(data = data %>% filter(time_edit >= 0 & time_edit <= input$time), 
                      aes(x=time_edit,y=linVel_sm), colour="blue")+
            geom_vline(xintercept=input$time,colour="red",size=1)+
            coord_cartesian(xlim = c(min(data$time_edit),max(data$time_edit)),ylim=c(min(data$linVel),max(data$linVel)))+
            labs(x="Time",
                 y="Linear Velocity (cm/sec)")+
            theme_classic()

    })
    
    output$angVelPlot <- renderPlot({
            ggplot() +
            geom_point(data = data, aes(x = time_edit, y = angVel), size = 1L, colour = "gray50") +
            geom_point(data = data %>% filter(time_edit >= 0 & time_edit <= input$time),
                       aes(x = time_edit, y = angVel))+
            geom_line(data = data %>% filter(time_edit >= 0 & time_edit <= input$time),
                      aes(x = time_edit, y = angVel_sm), colour="blue")+
            geom_vline(xintercept=input$time,colour="red",size=1)+
            coord_cartesian(xlim = c(min(data$time_edit),max(data$time_edit)),ylim=c(min(data$angVel),max(data$angVel)))+
            labs(x="Time",
                 y="Angular Velocity (Degrees/sec)")+
            theme_classic()
        
    })
    
    output$mapPlot <- renderPlot({
        ggplot(data)+
            aes(x=cm.xnew,y=cm.ynew,xend=sn.x,yend=sn.y)+
            geom_segment(arrow = arrow(length=unit(0.1,"inches")), colour="gray75")+
            geom_segment(data=data %>%
                             filter(time_edit >= 0 & time_edit <= input$time),arrow = arrow(length=unit(0.1,"inches")))+
            geom_segment(data=data %>%
                             filter(time_edit == input$time),arrow = arrow(length=unit(0.1,"inches")), colour="red")+
            geom_point(aes(x=max(data$tube.x),y=max(data$tube.y)), colour="red", size=2)+
            coord_cartesian(xlim = c(min(data$sn.x,data$cm.xnew,data$tube.x)-20,max(data$sn.x,data$cm.xnew,data$tube.x)+20),ylim=c(min(data$sn.y,data$cm.ynew,data$tube.y)-20,max(data$sn.y,data$cm.ynew,data$tube.y)+10))+
            labs(x="x",
                 y="y",
                 title = paste0("Loaction at ", input$time))+
            theme_classic()+
            theme(plot.title = element_text(hjust=0.5, size=16, face = "bold"))
    })
    
    observeEvent(input$ablend, {
        lend <- input$time
        save(lend, file="templend.RData")
        output$lend <- renderText({
        paste0("Latency end at: ", lend," seconds")})
    })
    
    
    observeEvent(input$abp1end, {
        p1end <- input$time
        save(p1end, file="tempp1end.RData")
        output$p1end <- renderText({
        paste0("Phase 1 end at: ", p1end," seconds")
            })
    })
    
    observeEvent(input$close, stopApp())
    
}

# Run the application 
shinyApp(ui = ui, server = server)
