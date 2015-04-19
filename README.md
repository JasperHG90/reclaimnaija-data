# Project files to download election reports from www.reclaimnaija.net
### Written by: Jasper Ginn (Jasperginn@hotmail.com)
### Date: 03-02-2015

This folder contains the python scripts to download the 2011 and 2015 election reports from www.reclaimnaija.net. At this point, the 2011 reports are no longer available for download. However, the scripts and the SQLite database are still available for download in the 'elections_2011' folder.

## Sample report url

Find a sample of a filed report here: http://reclaimnaija.net/reports/view/7

## Folder structure

/Analysis:

	* Naija_access.R 

		- R script with several analyses of the 2011 & 2015 reclaimnaija data
		
/Elections_2011:
	* /Data
		* Naija_sec.db
			- SQLite database that contains +- 8.000 reports filed to reclaimnaija about the 2011 Nigerian elections. (find a description of the variables below)
	* /Python
		* NAIJA.log
			- Log file from the scraping process. 
		* Naija_scrape.py
			- Python script used to scrape the reports for the 2011 Nigerian elections.
/Elections_2015
	* /Data
		* Naija_sec.db
			- SQLite database that contains +- 15.000 reports filed to reclaimnaija about the 2015 Nigerian elections. (find a description of the variables below)
	* /Python
		* NAIJA.log
			- Log file from the scraping process. 
		* Naija_scrape.py
			- Python script used to scrape the reports for the 2015 Nigerian elections.

## Variable description

| Variable   | Description                                            |
|------------|--------------------------------------------------------|
| URL        | URL of the report. Also functions as unique ID         |
| Date       | Date on which the report was filed to reclaimnaija.net |
| Location   | Report filer location                                  |
| Longitude  | Longitude of the report filer location                 |
| Latitude   | Latitude of the report filer location                  |
| Title      | Title of the report                                    |
| Report     | Text of the report                                     |
| Verified   | Whether or not the report was independently verified   |
| Category   | Category of the report                                 |
| Time       | Time of submission                                     |
| Scrapedate | Date on which the report was scraped.                  |