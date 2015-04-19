'
Rudimentary analyses of the data scraped from www.reclaimnaija.net

Structure:
 + Load packages
 + Retrieve data from db
 + Prep data
 + Explore data

Metadata:
 + Written by : Jasper Ginn
 + Date : 04-10-2014
 + Last modified: 16-02-2015
'

### Prep
rm(list=ls())
# Set wd
setwd("/Users/Jasper/Documents/github.projects/reclaimnaija/data/")

# Run line 32 twice IF you have to install packages. Otherwise, run it once to load packages
list.of.packages <- c("ggplot2",
                      "dplyr", 
                      "RSQLite", 
                      "lubridate", 
                      "scales", 
                      "ggmap", 
                      "raster", 
                      "rgdal",
                      "RJSONIO",
                      "data.table")
for (package in list.of.packages) if(!require(package, character.only=TRUE)) install.package(package)

# Connect to SQLite db! (make sure it is in your working directory)
db<-dbConnect(SQLite(), dbname=paste("NAIJA_sec.db",
                                     sep=""))

#### READING DATA FROM DB

# Read complete dataset
data <- dbReadTable(db, "NAIJA_tab")

# Read only data from a certain period
data <- dbSendQuery(db, "SELECT * FROM NAIJA WHERE Date = '2014-08-09'")
# Fetch data
data <- dbFetch(data)

# Read only one specific variable
data <- dbSendQuery(db, "SELECT Date FROM NAIJA")
# Fetch data
data <- dbFetch(data)

# Close connection
dbDisconnect(db)

#### Prep

str(data)
# Transform data
data$Date <- as.Date(ymd(data$Date))
data$Scrapedate <- as.Date(ymd(data$Scrapedate))
data$Verified <- as.factor(data$Verified)
data$Category <- as.factor(data$Category)
# check
str(data)
head(data)

#### Plotting

# How many reports verified?
ggplot(data, aes(x=Verified)) +
  geom_bar() +
  theme_bw()
# . . . ok, so very very little reports are actually verified
summary(data$Verified)

# Look at categories and visualize top ten
topcats <- data.frame(table(data$Category)) %>%
  arrange(., desc(Freq))
topcats <- topcats[1:10,]

ggplot(topcats, aes(x=reorder(Var1, Freq), y = Freq)) +
  geom_bar(stat = 'identity') +
  theme_bw() + 
  coord_flip()
# You should probably look at what those categories mean!

# Check unique geolocation points
data$GEOcomb <- paste0(data$Longitude, ", ", data$Latitude)
uniqGeo <- data %>%
  group_by(GEOcomb) %>%
  summarize(count=n()) %>%
  arrange(., desc(count))
# There were +- 150 reports that could not be geolocated. Let's mark these with a 1 or 0 binary variable so we can easily take them out if necessary.
data$GEO_true <- ifelse(data$GEOcomb == "0, 0", 0, 1)

# Let's plot reports over time, for funsies. I am using the %>% chaining command from the dplyr package. Very useful, you should look into it!

dataOT <- data %>%
  group_by(Date) %>%
  summarize(count = n()) %>%
  arrange(., desc(count))

# Let's look at the day on which most reports came in
data_mostfreq <- data[which(data$Date == '2011-04-02'),]

# create date + timestamp and plot for a daily overview
data_mostfreq$DateTime <- paste0(data_mostfreq$Date, ' ', data_mostfreq$Time)
# Convert to datetime format
data_mostfreq$DateTime <- as.POSIXct(data_mostfreq$DateTime)

# Plot
p <- qplot(data_mostfreq$DateTime) + 
  xlab("Time slot") +
  scale_x_datetime(breaks=("2 hour"), 
                   minor_breaks=("1 hour"), 
                   labels=date_format("%H:%M")) + 
  theme_bw() + 
  theme(strip.background = element_rect(fill = 'white')) #+ 
  #ggtitle(paste("Scrape intensity on",datetoday,sep=" "))
print(p)
# . . . People seem to vote between most 7-8. Why then? Not quite sure. There is a peak before 9 AM, and a peak after five PM.

### Rudimentary map of geolocations

# Firstly, take out all observations that have 0,0 as geolocations. There are no geolocations for these observations.
data <- data[which(data$GEO_true == 1),]

# Fetch a google map
NIG.map <- get_map(location = "Nigeria", maptype = "hybrid",
                  color = "bw", zoom = 6)
# Download shapefile with administrative regions
shpData <- getData('GADM', country='Nigeria', level=1)
# Transform to WGS84 coordinate system
shpData <- spTransform(shpData, CRS("+proj=longlat +datum=WGS84"))
# Fortify shapefile so ggmap can read it
shpData <- fortify(shpData)
# plot map + shapefile
nigMap <- ggmap(NIG.map) + geom_polygon(aes(x=long, y=lat, group=group), 
                                      data=shpData, color ="blue", fill ="blue", alpha = .1, size = .3)
# plot (map + shapefile) + datapoints
nigMap + geom_point(data = data, aes(x = Longitude, y = Latitude), 
                   color = "darkred", alpha = 0.8, size = 3) + 
  scale_colour_manual(values=c("blue","red"))
# Density plot
nigMap + geom_density2d(mapping=aes(x = Longitude, y = Latitude),
                         data = data, colour="Red") 
# The density plot shows that there are a lot of 'generic' geolocations (i.e. standard geolocations from e.g. 'Osun state'.) Not necessarily problematic, but be aware.

## Some of these geolocations are at sea for some inexplicable reason. Let's see if we can select these. Also, ggmap deletes the points that fall from the map. We can look at this by simply plotting the geolocations in a scatterplot

ggplot(data, aes(x=Longitude, y=Latitude)) +
  geom_point() +
  theme_bw()

# Ya ok, so either people are sending in reports from abroad . . . or some fucky stuff is going on here. Let's kick out these foreign reports. They are not representative
ggplot(data, aes(x=Longitude, y=Latitude)) +
  geom_point() +
  scale_y_continuous(breaks=c(seq(from=0, to=62, by = 3))) +
  theme_bw() +
  geom_hline(yintercept=16, colour="red", size=2) +
  geom_vline(xintercept=16, colour="green", size=2) +
  geom_rect(data = data, aes(xmin = -Inf, xmax = 16, 
                             ymin = -Inf, ymax = 16),
                            fill="lightgrey",
                            alpha = 0.02) 
# Yes. this plot is a bit to show off, but it shows us that we can select all the geolocations that fall outside of the shaded area.
data_outNaija <- data[which(data$Longitude >= 16 & data$Longitude >= 16),]

# Ok  . . . so where are these places? Luckily, I adapted a function from http://bit.ly/19nbvdK to look this up by geolocation some time ago. 

# Convert Long/Lat to character format
data$CharLat <- sprintf("%f", data$Latitude)
data$CharLong <- sprintf("%f", data$Longitude)

### Reverse code the Geolocations (i.e. input geolocations, get placenames)
RevGeo <- function(latlong_combination){
  # Join Lat/Long values
  latlng <- latlong_combination
  # Paste 
  latlngStr <-  gsub(' ','%20', paste(latlng, collapse=","))
  # Convert to URL
  connectStr <- paste('http://maps.google.com/maps/api/geocode/json?sensor=false&latlng=',
                      latlngStr, sep="")
  # Open connection
  con <- url(connectStr)
  # Load JSON data
  data.json <- fromJSON(paste(readLines(con), collapse=""))
  # Close connection
  close(con)
  #data.json <- unlist(data.json)
  # Extract country name
  if(data.json["status"]=="OK"){
    country <- data.json$results[[1]]$formatted_address
  }else{
    country <- ""
  }
  # Return data
  return(country)
}

data_outNaija$locations <- unlist(lapply(data_outNaija$GEOcomb, RevGeo))
# I don't have a direct explanation for why these guys would file complaints from Saudi Arabia and yemen etc. But this is definitely of interest for you! Maybe these guys have anonimized their internet connection? ANyways, they are prime candidates for being removed IF it turns out that the geolocating process isn't as accurate as reclaimnaija professes.
         
# There are few and dispersed reports after 2011 (prob local elections). Select for observations in 2011

dataOT <- filter(dataOT, Date <= '2011-12-31')

# Plot

ggplot(dataOT, aes(x=Date, y=count)) + 
  geom_line(size=2, alpha=0.8) + theme_bw() + geom_point(size=5) + 
  theme(strip.background = element_rect(fill = 'white')) + 
  xlab("Year") +
  ylab("Number of Events")

## Is this good? Bad? I dunno, I'll leave that to you to decide.

