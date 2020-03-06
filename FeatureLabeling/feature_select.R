### This script will import images (grouped by several factors), prompt to select 
### specific features across multiple images, randomly select 5 of the selected features,
### and save the marked up images.


{
  ## Prep
  library(raster)
  library(stringr)
  library(here)
  
  # Set starting point
  imgnum <- 1
  
  # Set number of features to select
  cat("\n\n")
  featnum <- as.numeric(readline("How many features would you like to randomly pick from selected options? "))
  
  # make sure a value >0 is selected
  if(featnum<1){
    warning("A number > zero must be chosen")
    rm(featnum)
  }
  
  # Make vector of images in folder respository
  img_orig_loc <- here("img_orig")
  imgs <- dir(path=img_orig_loc,
              pattern=".tif")
  
  # Set save location
  img_save_loc <- here("img_save")
  
  # We need to separate based on unique 
  # combos of the fist and second objects when separated 
  # by '_' then extract unique (to get individual crab, leg combo)
  subject <- unique(unlist(lapply(strsplit(imgs,"_"), function(x) paste(x[1],x[2], sep='_'))))
  
  # make color scale to set photos to gray scale
  grayscale_colors <- gray.colors(100, 
                                  start = 0.0,
                                  end = 1.0,
                                  gamma = 2.2,
                                  alpha = NULL)

## Loop
while(imgnum<=length(subject)){
  
  # double check that a number of points was selected
  if(!exists("featnum")){
    print("You must select a number of features to randomly pick.")
    break
    } 
  
  # get images for the crab of interest
  focusimgs <- imgs[grep(subject[imgnum],imgs)]
  
  dataout <- data.frame(x=c(),y=c(),img=c()) # create empty dataframe
  for(i in focusimgs) {
    # Display Image
    img <- raster(here("img_orig",i)) # import image
    plot(img, 
         col=grayscale_colors, 
         axes=FALSE, 
         box=FALSE, 
         legend=FALSE, 
         main=paste0("Select features from image ",i))
    
    # Have user select points
    print("Waiting for selection. Hit 'Finish' in upper right of plot or escape when selection is complete.")
    cat("\n")
    
    locs <- locator(type="p", pch=16, col="red")
    cat("\n")
    print("Selection Complete")
    cat("\n")
    
    # Create NA output if no point was selected
    if(length(locs)!=0){
      locs <- data.frame(x=locs$x,y=locs$y,img=i)
    } else {
      locs <- data.frame(x=NA,y=NA,img=i)
    }
    
    # combine with other images of same crab, leg combo
    dataout <- rbind(dataout,locs)
  }
  
  dataout$img <- as.character(dataout$img)
  
  # Randomly pick points out of selected features.
  # If we have = or more than the requested number of features
  if(length(na.omit(dataout$x))>=featnum){
    rowkeep <- sample(1:length(dataout$x),featnum,replace = FALSE) 
    dataout$select <- NA 
    dataout[rowkeep,4] <- 1:featnum
  }
  # If we have less than the requested number of features
  if(length(na.omit(dataout$x))<featnum){
    cat("\n")
    print("Number of points selected < requested number selected. The number of points chosen will = number of points marked.")
    cat("\n")
    featnumtemp <- length(locs$x)
    rowkeep <- sample(1:length(dataout$x),featnumtemp,replace = FALSE) 
    dataout$select <- NA 
    dataout[rowkeep,4] <- 1:featnumtemp
  } 
  # If we have no features selected
  if(length(na.omit(dataout$x))==0){
    cat("\n")
    print("No points selected.")
    cat("\n")
    dataout$select <- NA 
  }
  
  # Replot to add points and labels
  for(i in focusimgs){
    imgsub <- raster(here("img_orig",i)) # reload images individually
    poi <- subset(dataout,img==i) # pull out selected points for the particular image
    good <- poi[!is.na(poi$select),] # subset those points picked
    bad <- poi[is.na(poi$select),] # subset those points not picked
    # Modify image name
    
    fname <- paste0(str_sub(i,end=-5),"_pts.png") # create file name for output
    png(file=here("img_save",fname),height = 400,width=600,units="px") # open graphics device for output
    plot(imgsub, col=grayscale_colors, axes=FALSE, box=FALSE, legend=FALSE) # plot
    if(exists("bad")==TRUE){
      points(bad$x,bad$y,pch=16,col="red") # plot unselected points in red
    }
    if(exists("good")==TRUE){
      points(good$x,good$y,pch=16,col="green") # plot selected points in green
      points(good$x+30,good$y+30,pch=as.character(good$select),col="green") # and label with the selection number
    }
    
    # output image w/ modified name
    dev.off() # close graphics device
    
    # remove before next loop
    suppressWarnings(rm(good,bad,poi, featnumtemp)) 
  }
  
  # Ask exit or next
  # if exit, exit
  # if next, vector +1
  
  q1 <- menu(c("Yes","No"),title="Do you want to go to the next image?")
  if(q1==1){
    imgnum <- imgnum+1
  }
  if(q1==2){
    print(paste0("The next image starting position (imgnum; line 12) would be ",imgnum+1))
    break
  }
}

}
