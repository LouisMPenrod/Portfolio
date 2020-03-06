### This script was to test teh possibilty to use tracking data of two fish
### to calculate the cumulative time in different zones, but more importantly,
### create and animation that shows the position of the fish and the cumulative
### time in each zone.

## prep
library(here)
library(ggplot2)
library(gganimate)
library(animation)
library(plyr)
library(scales)
library(purrr)
library(magick)


## Create test data
x<-c(.1,.11,.12,.11,.2,.4,.7,.85,.9,.85,.91,.6,.45,.3,.2,.1)
y<-c(.4,.5,.45,.6,.5,.6,.6,.5,.3,.2,.2,.25,.15,.15,.2,.2)
time<-rep(1:8,2)
fish<-rep(letters[1:2],each=8)
test<-data.frame(x,y,time,fish)


## Define and label zones
for(i in 1:length(test$x)){
  to_test<-test[i,]
  if(to_test$x>=0&to_test$x<0.25){
    test[i,5]<-"blue"
  }
  if(to_test$x>=0.25&to_test$x<0.5){
    test[i,5]<-"black"
  }
  if(to_test$x>=0.5&to_test$x<0.75){
    test[i,5]<-"yellow"
  }
  if(to_test$x>=0.75&to_test$x<=1){
    test[i,5]<-"green"
  }
}

test[,5]<-factor(test[,5])
colnames(test)[5]<-"zone"


## Calculate cumulative time in each zone
hold<-data.frame()
for(i in test$time){
  newtest<-subset(test,test$time<=i,select = c("fish","zone"))
  testp<-data.frame(t(prop.table(table(newtest),1)))
  time<-rep(i,length(testp$zone))
  testp<-cbind(testp,time)
  hold<-rbind.fill(hold,testp)
}


## Plot
fill<-c("black","blue","green","yellow")

# plot tracking
p<-ggplot(test,aes(x,y,colour=fish))+
  geom_rect(mapping = aes(xmin=0,xmax=0.25,ymin=0,ymax=1),fill="blue",color="black",alpha=0.1)+
  geom_rect(mapping = aes(xmin=0.25,xmax=0.5,ymin=0,ymax=1),fill="black",color="black",alpha=0.1)+
  geom_rect(mapping = aes(xmin=0.5,xmax=0.75,ymin=0,ymax=1),fill="yellow",color="black",alpha=0.1)+
  geom_rect(mapping = aes(xmin=0.75,xmax=1,ymin=0,ymax=1),fill="green",color="black",alpha=0.1)+
  geom_point(cex=2)+
  xlim(0,1)+
  ylim(0,1)+
  theme_void()+
  labs(title = "Position of fish in tank", subtitle='Time: {frame_time}')+
  theme(plot.title = element_text(hjust=0.5, size=14,face='bold'),
        plot.subtitle = element_text(hjust=0.5))+
  transition_time(time)+
  ease_aes('linear')
p
ani.options(ani.height=200,interval=0.001)
anim_save("track.gif")

# plot cumulative time
p2<-ggplot(hold)+
  geom_bar(aes(x=fish,y=Freq/2,fill=zone),stat = "identity",alpha=0.5)+
  scale_fill_manual(values=fill)+
  scale_y_continuous(labels=scales::percent)+
  labs(x="Fish", y="Cumulative time", title = "Cumulative time spent in each zone",subtitle = "Time: {frame_time}")+
  theme_minimal()+
  theme(plot.title = element_text(hjust=0.5, size=14,face='bold'),
        plot.subtitle = element_text(hjust=0.5),
        axis.title = element_text(face="bold"),
        axis.title.y = element_text(vjust = 3),
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        plot.margin = unit(c(5.5,5.5,5.5,45),"points"))+
  transition_time(time)+
  ease_aes('linear')
p2
anim_save("bars.gif")


## combine saved animations into single animation
map2(
  "track.gif" %>% image_read() %>% as.list(),
  "bars.gif" %>% image_read() %>% as.list(),
  ~image_append(c(.x, .y))
) %>%
  lift(image_join)(.) %>%
  image_write("result.gif")

## Remove intermediate files (optional)
# c("track.gif", "bar.gif") %>% walk(unlink)
