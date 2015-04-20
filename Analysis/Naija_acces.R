'
Rudimentary analyses of the reports on the 2011 & 2015 elections scraped from www.reclaimnaija.net

Metadata:
 + Written by : Jasper Ginn
 + Date : 04-10-2014
 + Last modified: 19-04-2015
'

# Prep ----

rm(list=ls())
# Set wd
setwd("/Users/Jasper/Documents/github.projects/reclaimnaija/")
# Datasets for the 2011 & 2015 elections
data.dir <- c(paste0(getwd(),"/Elections_2011/Data/NAIJA_sec.db"),
              paste0(getwd(),"/Elections_2015/Data/NAIJA_sec.db"))
# Run line 30 twice IF you have to install packages. Otherwise, run it once to load packages
list.of.packages <- c("ggplot2",
                      "dplyr", 
                      "RSQLite", 
                      "lubridate", 
                      "scales", 
                      "ggmap", 
                      "raster", 
                      "rgdal",
                      "RJSONIO",
                      "data.table",
                      "XML")
for (package in list.of.packages) if(!require(package, character.only=TRUE)) install.package(package)

# Take datasets for both elections
dt <- lapply(data.dir, function(x){
  # Connect to db
  db <- dbConnect(SQLite(), dbname=x)
  # Read Table
  tab <- dbReadTable(db, "NAIJA_tab")
  # Disconnect
  dbDisconnect(db)
  # Add identifier
  if(grepl("Elections_2011", x) == TRUE){
    tab$year <- "2011"
  } else{
    tab$year <- "2015"
  }
  # Return
  return(tab)
})
# Reduce to one dataset
data <- rbindlist(dt)
rm(dt)

# Process -----

# Check
str(data)

# Trim trailing whitespace
trimWS <- function (x) gsub("^\\s+|\\s+$", "", x)
data$Verified <- trimWS(data$Verified)
data$Category <- trimWS(data$Category)
data$Report <- trimWS(data$Report)

# Transform data
data$Date <- as.Date(ymd(data$Date))
data$Scrapedate <- as.Date(ymd(data$Scrapedate))
data$Verified <- as.factor(data$Verified)
data$Category <- as.factor(data$Category)
data$year <- as.factor(data$year)

# Check
str(data)

# EDA -----

# Let's plot reports over time, for funsies. I am using the %>% chaining command from the dplyr package. Very useful, you should look into it!

dataOT <- data %>%
  group_by(Date) %>%
  summarize(count = n()) %>%
  arrange(., desc(count)) # The elections in 2011 were held on 16-04. In 2015 they were held on 28 & 29 March. However, not many reports actually came in on these dates. Perhaps they are only published after review.

# Plot over time

ggplot(dataOT, aes(x=Date, y=count)) + 
  geom_line(size=2, alpha=0.8) + theme_bw() + geom_point(size=5) + 
  theme(strip.background = element_rect(fill = 'white')) + 
  xlab("Year") +
  ylab("Number of Events") # Not pretty, but shows us that reports trickle in before and after elections. Bit nonsensical

# How many reports verified?
p <- ggplot(data, aes(x=Verified)) +
  geom_bar() +
  theme_bw()
p + facet_grid(. ~ year)
# . . . ok, so very very little reports are actually verified
tapply(data$Verified, data$year, summary)
# Look at reports that are neither verified nor unverified
d2015 <- data[data$year == "2015",]
d2015[d2015$Verified == "",] # These are actually all verified. SOmething must have gone when scraping the site >.<

# Look at categories and visualize top ten
topcats2011 <- data.frame(table(data[data$year == "2011",]$Category)) %>%
  arrange(., desc(Freq)) %>%
  mutate(., year = "2011")
topcats2011 <- topcats2011[1:10,]
topcats2015 <- data.frame(table(data[data$year == "2015",]$Category)) %>%
  arrange(., desc(Freq)) %>%
  mutate(., year="2015")
topcats2015 <- topcats2015[1:10,]
# Combine
topcats <- rbind(topcats2011, topcats2015)
# No caps
topcats$Var1 <- tolower(topcats$Var1)
# Plot
p <- ggplot(topcats, aes(x=reorder(Var1, Freq), y = Freq)) +
  geom_bar(stat = 'identity') +
  theme_bw() + 
  coord_flip() +
  theme(axis.title.x = element_blank(),
        axis.title.y = element_blank())
p + facet_grid(. ~ year)
# You should probably look at what those categories mean!

# Check unique geolocation points
data$GEOcomb <- paste0(data$Longitude, ", ", data$Latitude)
uniqGeo <- data %>%
  group_by(GEOcomb) %>%
  summarize(count=n()) %>%
  arrange(., desc(count))
# There were +- 150 reports that could not be geolocated. Let's mark these with a 1 or 0 binary variable so we can easily take them out if necessary.
data$GEO_true <- ifelse(data$GEOcomb == "0, 0", 0, 1)

# Let's look at the day on which most reports came in
data_mostfreq <- data[which(data$Date == '2015-04-11'),] 

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
# Hm. Doesn't really seem as a continuous flow.

### Rudimentary map of geolocations

# Firstly, take out all observations that have 0,0 as geolocations. There are no geolocations for these observations.
data <- data[which(data$GEO_true == 1),]

# Fetch a google map
NIG.map <- get_map(location = "Nigeria", maptype = "hybrid",
                  color = "bw", zoom = 6)
# Download shapefile with administrative regions
shpData <- getData('GADM', country='Nigeria', level=1)
shpData$NAME_1
# Transform to WGS84 coordinate system
shpData <- spTransform(shpData, CRS("+proj=longlat +datum=WGS84"))
# Fortify shapefile so ggmap can read it
shpData <- fortify(shpData)
# plot map + shapefile
nigMap <- ggmap(NIG.map, extent = "panel", maprange=FALSE) + 
  geom_polygon(aes(x=long, y=lat, group=group), 
                                      data=shpData, color ="blue", fill ="blue", alpha = .1, size = .3)
# plot (map + shapefile) + datapoints (2011)
ch1 <- nigMap + geom_point(data = data[data$year == "2011",], aes(x = Longitude, y = Latitude), 
                   color = "darkred", alpha = 0.8, size = 3) 
# Add data for 2015
ch1 + geom_point(data = data[data$year == "2015",], aes(x = Longitude, y = Latitude),
             color = "darkgreen", alpha=0.8, size = 3) 
# Density plot
ch2 <- nigMap + geom_density2d(mapping=aes(x = Longitude, y = Latitude),
                         data = data[data$year == "2011",], colour="Red") 
# Add 2015
ch2 + geom_density2d(mapping=aes(x = Longitude, y = Latitude),
                     data = data[data$year == "2015",], colour="Green") # Overlapping areas, although 2015 is more comprehensive
# Facet plot
ch3 <- nigMap + 
  geom_density2d(data = data, aes(x = Longitude, y = Latitude), colour="black") +
  stat_density2d(data = data, aes(x = Longitude, y = Latitude,  fill = ..level.., alpha = ..level..),
                 size = 0.01, bins = 20, geom = 'polygon') +
  scale_fill_gradient(low = "green", high = "red") +
  scale_alpha(range = c(0.00, 0.5), guide = FALSE) +
  theme(legend.position = "none", 
        axis.title = element_blank(), 
        text = element_text(size = 12))
ch3 + facet_grid(. ~ year) + ggtitle("Geographic Density of Reports Posted to www.reclaimnaija.net in 2011 and 2015")
# The density plot shows that there are a lot of 'generic' geolocations (i.e. standard geolocations from e.g. 'Osun state'.) Not necessarily problematic, but be aware.

# What is the population density by state? Get a quick table from wikipedia
url <- "http://en.wikipedia.org/wiki/List_of_Nigerian_states_by_population"
pop <- as.data.frame(readHTMLTable(url)[1])
str(pop)
colnames(pop) <- c("Rank", "State", "Population")
pop$Rank <- as.numeric(pop$Rank)
# Sub all commas in pop figures and make numeric
pop$Population <- as.character(pop$Population)
pop$Population <- as.numeric(gsub(",", "", pop$Population))
# Sub all "State" in the state names
pop$State <- gsub(" State", "", pop$State)
# Lower
pop$State <- tolower(pop$State)
# load shapedata with admin regions
nig.m.2 <- readOGR(dsn = paste0(getwd(), "/Analysis"), 
                   layer = "NIR-level_1")
states <- data.frame(statename = as.character(nig.m.2$ID),
                       id = 1:40,
                       stringsAsFactors=F)
# Alter name
states$statename[17] <- "Abuja Federal Capital Territory"
states$statename[28] <- "Nasarawa"
# Lower
states$statename <- tolower(states$statename)
# Merge
statespop <- merge(states, pop, by.x="statename", by.y="State", all=TRUE)
# Transform to WGS84 coordinate system
shpData <- spTransform(shpData, CRS("+proj=longlat +datum=WGS84"))
# Fortify shapefile so ggmap can read it
nig.m.2$STATE <- as.character(nig.m.2$ID)
nig.m.2$ID <- as.factor(1:40)
shpData <- fortify(nig.m.2)
shpData$id <- as.character(as.numeric(shpData$id) + 1)
# Merge
shpData.m <- merge(statespop, shpData, by.x="id", by.y="id")
# plot map + shapefile
ggmap(NIG.map, extent = "panel", maprange=FALSE) + 
  geom_polygon(aes(x=long, y=lat, group=group), 
               data=shpData, color ="black", fill ="blue", alpha=0.8,size=0.3)



## Some of these geolocations are at sea for some inexplicable reason. Let's see if we can select these. Also, ggmap deletes the points that fall from the map. We can look at this by simply plotting the geolocations in a scatterplot

ggplot(data, aes(x=Longitude, y=Latitude)) +
  geom_point() +
  theme_bw()

# Ya ok, so either people are sending in reports from abroad . . . or some fucky stuff is going on here. Let's kick out these foreign reports. They are not representative
ggplot(data, aes(x=Longitude, y=Latitude)) +
  geom_point(colour = data$year) +
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

