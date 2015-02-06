## MOJO JOJO! Please follow script to see how to retrieve Naija data

### Prep
rm(list=ls())
# Set wd
setwd("/Users/Jasper/Documents/github.projects/reclaimnaija/data/")
# Run this function! It will install packages you need but might not have :)
Nespack <- function(){ 
  list.of.packages <- c("ggplot2","dplyr", "RSQLite", "lubridate")
  new.packages <- list.of.packages[!(list.of.packages %in% 
                                       installed.packages()
                                     [,"Package"])]
  if(length(new.packages)){
    install.packages(new.packages) 
  }
}
# And go!
Nespack()
# Load packages
require(ggplot2) ; require(dplyr) ; require(RSQLite) ; require(lubridate)

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

#### Plotting

# Let's plot reports over time, for funsies. I am using the %>% chaining command from the dplyr package. Very useful, you should look into it!

dataOT <- data %>%
  group_by(Date) %>%
  summarize(count = n())

# Turn the date variable into a date class
dataOT$Date <- as.Date(ymd(dataOT$Date))

# There are few and dispersed reports after 2011 (prob local elections). Select for observations in 2011

dataOT <- filter(dataOT, Date <= '2011-12-31')

# Plot

ggplot(dataOT, aes(x=Date, y=count)) + 
  geom_line(size=2, alpha=0.8) + theme_bw() + geom_point(size=5) + 
  theme(strip.background = element_rect(fill = 'white')) + 
  xlab("Year") +
  ylab("Number of Events")

## Is this good? Bad? I dunno, I'll leave that to you to decide.

# Let me know if you need some help turning this into geolocated data.