### This script takes a dataframe with the xy coordinates and time for
### the stimulus, fish snout, and center of mass to calculate various metrics
### like angle from stimulus, orientation, turning velocity, turing acceleration, 
### linear velocity, and linear acceleration. It also implements a shiny app to
### assist in determining the phases of the fish's response.

## Prep work
{
  library(here)
  library(LearnGeom)
  library(shiny)
  library(dplyr)
  
  ## Pull files from folder
  files <- list.files(here("raw_data","response"))
  
  ## set number to what file you want to start on
  vid <- 1
  
  cont <- TRUE
}

### Calculate metrics

while(vid <= length(files) & cont==TRUE) {
  
  ## load requested video
  data <- read.csv(here("raw_data","response",files[vid])) # load data
  
  ## Fix time column from Kinovea output format
  t2 <- lapply(strsplit(as.character(data$t),":"),function(x) as.numeric(x))
  t2_2 <- unlist(lapply(t2,function(x) (x[1]*3600)+(x[2]*60)+(x[3])+(x[4]/1000)))
  data$time_edit <- round(t2_2,digits=3) # create new column for corrected time format
  
  
  ## add time displacement (t[n]-t[n-1])
  thold <- NA
  for(i in 2:length(data$time_edit)){
    tdisp <- data$time_edit[i]-data$time_edit[i-1]
    thold <- c(thold,tdisp)
  }
  data$tdisp <- thold # create new column for time displacement
  
  
  ## calculate distance from tube to snout
  data$dT2S <- sqrt((data$tube.x-data$sn.x)^2+(data$tube.y-data$sn.y)^2)
  
  
  ## calculate x&y displacement from tube to snout
  data$xS2T <- data$sn.x-data$tube.x # positive means fish right of tube, negative means left of tube
  data$yT2S <- data$tube.y-data$sn.x # positive means above tube, negative means below tube
  
  
  ## correct CM placement 
  ## Kinovea's auto-tracker works on well on placeing the cm
  ## on the midline of the fish however it is poor at maintaing the same position
  ## along the midline.
  ## Start by calculating the distance from the snout the the cm. We want to
  ## maintain the same distance as at the first frame. Then use trig to shift the
  ## x & y coordinates along the same angle between the snout and cm to the set
  ## distance from frame 1. 
  data$dS2CM <- sqrt((data$sn.x-data$cm.x)^2+(data$sn.y-data$cm.y)^2) # calc dist between snout and CM
  data$cm.xnew <- data$sn.x-((data$dS2CM[1]*(data$sn.x-data$cm.x))/data$dS2CM) # reset cm x
  data$cm.ynew <- data$sn.y-((data$dS2CM[1]*(data$sn.y-data$cm.y))/data$dS2CM) # reset cm y
  ## to check that this worked run:
  # table(sqrt((data$sn.x-data$cm.xnew)^2+(data$sn.y-data$cm.ynew)^2))
  ## you should get one value (possibly two very similar values due to rounding) 
  
  
  ## calcualte displacement of snout and cm frame to frame. Needed for velocity and accel calcs
  evsn <- NA # set starting point
  evcm <- NA # set starting point
  
  for(i in 2:length(data$sn.x)){
    sndisp <- sqrt((data$sn.x[i]-data$sn.x[i-1])^2+(data$sn.y[i]-data$sn.y[i-1])^2) # distance between snout[n] and snout[n-1]
    cmdisp <- sqrt((data$cm.xnew[i]-data$cm.xnew[i-1])^2+(data$cm.ynew[i]-data$cm.ynew[i-1])^2) # distance between cm[n] and cm[n-1]
    evsn <- c(evsn,sndisp) # combine with previous numbers created in for loop
    evcm <- c(evcm,cmdisp) # combine wiht previous numbers created in for loop
  }
  
  data$sn2sn <- evsn # make column of snout to snout displacement
  data$cm2cm <- evcm # make column of cm to cm displacement
  
  
  ## calculate angle from vertical
  maxval <- max(c(data$sn.y,data$cm.ynew,data$tube.y))+20 # get point that will always be > than any other in y direction
  ang <- c() # make empty vector
  for(i in 1:length(data$sn.x)){
    # calculate absolute angle
    focusang <- Angle(A=c(data$cm.xnew[i],maxval),B=c(data$cm.xnew[i],data$cm.ynew[i]),C=c(data$sn.x[i],data$sn.y[i])) # each vector in x,y format
    ang <- c(ang,focusang)
  }
  data$orien <- ang # make into column
  
  # Want to get directional angle (clock-wise vs counter), not absolute angle
  dir <- data.frame(dir=data$cm.xnew-data$sn.x) # get orientation of x (pos=left, neg=right)
  dir <- dir %>% 
    mutate(dir2=if_else(dir<=0,-1,1)) # simplify to just give indicator of direction
  
  temp <- data.frame(ang=ang,dir=dir)
  
  ang3 <- c()
  for (i in seq_along(temp[,1])){
    if(temp[i,3]>0){
      val<-temp[i,1] # if indicator is positive, maintain angle
    }
    if(temp[i,3]<0){
      val<-360-temp[i,1] # if indicator is negative, take 360-angle
    }
    ang3 <- c(ang3,val)
  }
  
  data$dorien <- ang3 # make into column
  
  
  ## calculate angle between tube, cm, and snout. Probably won't need for ananlysis but create just in case.
  ang2 <- c() # make empty vector
  for(i in 1:length(data$sn.x)){
    # calculate absolute angle
    focusang2 <- Angle(A=c(data$tube.x[i],data$tube.y[i]),B=c(data$cm.xnew[i],data$cm.ynew[i]),C=c(data$sn.x[i],data$sn.y[i])) # each vector in x,y format
    ang2 <- c(ang2,focusang2)
  }
  # do not care about absolute vs directional here
  data$angle <- ang2 # make new column
  
  
  ## calculate linear velocity
  data$linVel <- data$cm2cm/data$tdisp #vel=cm to cm displacement over time displacement
  data$linVel[1] <- 0 # cannot have a velocity at frame 1 but need a value for smoothing
  
  
  ## smooth linear velocity. Creates new points at all time_edit points.
  ## Used cv=TRUE to allow better smoothing (would not have one spar and df for all videos)
  data$linVel_sm <-smooth.spline(x=data$time_edit,y=data$linVel,all.knots = TRUE, cv=TRUE)$y
  
  
  ## calculate angular velocity (use orien)
  evav <- NA
  
  for(i in 2:length(data$orien)){
    angdisp <- (data$orien[i]-data$orien[i-1]) # calculate the angular displacement
    evav <- c(evav,angdisp)
  }
  data$oriendisp <- evav # make into column
  
  data$angVel <- data$oriendisp/data$tdisp #ang vel = ang displacement over time displacement
  data$angVel[1] <- 0 # cannot have a velocity at frame 1 but need a value for smoothing 
  
  # smooth angular velocity
  data$angVel_sm <- smooth.spline(data$time_edit,data$angVel, all.knots = TRUE, cv=TRUE)$y
  
  # calculate linear acceleration
  evla <- NA
  
  for(i in 2:length(data$linVel)){
    veldisp <- (data$linVel[i]-data$linVel[i-1]) # calculate velocity displacement
    evla <- c(evla,veldisp)
  }
  data$veldisp <- evla # make into column
  
  data$linAccel <- data$veldisp/data$tdisp # accel=vel displacement over time displacement
  data$linAccel[1] <- 0 # cannot have a accel at frame 1 but need a value for smoothing 
  
  
  ## smooth linear acceleration. Creates new points at all time_edit points.
  ## Used cv=TRUE to allow better smoothing (would not have one spar and df for all videos)
  data$linAccel_sm <- smooth.spline(data$time_edit,data$linAccel, all.knots = TRUE, cv=TRUE)$y
  
  
  ## calculate angular acceleration
  evaa <- NA
  
  for(i in 2:length(data$angVel)){
    aveldisp <- (data$angVel[i]-data$angVel[i-1]) # calc ang velocity displacement
    evaa <- c(evaa,aveldisp)
  }
  data$aveldisp <- evaa
  
  data$angAccel <- data$aveldisp/data$tdisp # ang accel = ang vel displacement over time displacement
  data$angAccel[1] <- 0 # cannot have a accel at frame 1 but need a value for smoothing 
  
  
  ## smooth angular acceleration. Creates new points at all time_edit points.
  ## Used cv=TRUE to allow better smoothing (would not have one spar and df for all videos)
  data$angAccel_sm <- smooth.spline(data$time_edit,data$angAccel, all.knots = TRUE, cv=TRUE)$y
  
  ## clean up global
  rm(t2,angdisp, ang,ang2,aveldisp,cmdisp,evaa,evav,evcm,evla,evsn,focusang,focusang2,i,maxval,sndisp,t2_2,tdisp,thold,veldisp, dir, temp, val, ang3)
  
  ## Run shiny app to determine timing of fish's turing phase.
  ## App creates three plots. The first is of the angular velocity through time,
  ## the second is the linear velocity through time,
  ## and the third is the position of the fish (arrow is head, red dot is stimulus).
  ## Run the app, use the slider to find the frame where the fish starts to turn and
  ## click the mark latency button. The move the slider to where the fish stops
  ## changing angle and starts moving forward (or sometime sideways). Click the
  ## mark phase 1 button. If you need to edit your selection, just move the slider
  ## and click the mark buttons again. 
  ## To close the app, MAKE SURE TO CLICK THE YELLOW CLOSE BUTTON or else the loop
  ## will stop!
  ## Your frame selection will be saved and loaded into the loop in the next step.
  suppressMessages(runApp(here("phases","app.R")))
  
  
  ## Get phases indicators from where they were saved.
  load(here("phases","templend.RData"))
  load(here("phases","tempp1end.RData"))
  file.remove(here("phases","templend.RData")) # remove files incase something goes wrong
  file.remove(here("phases","tempp1end.RData")) # remove file incase something goes wrong
  
  ## make new phase column
  rlend <- as.numeric(rownames(subset(data, time_edit==lend))) # get row name needed to be labeled as latency phase up to
  rp1end <- as.numeric(rownames(subset(data, time_edit==p1end))) # get row name needed to be labeled as phase1 up to
  rend <- nrow(data) # get total number of rows
  # create column with the proper number of latency, p1, and p2 (total-end of p1)
  data$phase <- c(rep("Lat",times=rlend),rep("P1",times=rp1end-rlend),rep("P2",time=rend-rp1end))
  
  ## output data
  fname <- files[vid] # create name for file (same as imported)
  write.csv(data,file=here("processed_data","response",fname),row.names=FALSE) # write data file
  # I want to save the phases in another df just incase something happens, I dont have to use the app again to go throught files
  phase_rec_out <- data.frame(vid=fname,lend=lend,p1end=p1end) # create row
  phase_rec <- read.csv(here("processed_data","phase_record.csv")) # load created data
  phase_rec <- rbind(phase_rec,phase_rec_out) # add row
  write.csv(phase_rec,file=here("processed_data","phase_record.csv"),row.names = FALSE) # save with new row added
  rm(phase_rec,phase_rec_out,data,fname,rlend,rp1end,rend,lend,p1end) # keep it clean
  
  ## add question to continue and loop to the next video
  ## question will pop up in the console. type 1 and enter to contiune,
  ## type 2 and enter to quit. Upon quitting, a note will popup 
  ## indicating the video number that will allow you to pick
  ## back up where you left off. Just replace vid <- 1 (line 17) with the new number.
  q1 <- menu(c("Yes","No"),title="Do you want to go to the next image?")
  if(q1==1){
    vid <- vid+1
  }
  if(q1==2){
    print(paste0("The next video would be ",vid+1))
    cont=FALSE
    break
  }
  rm(q1)
}
