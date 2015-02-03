'''
This script scrapes information about harrassment at the Nigerian 2011 & 2015 elections from www.reclamnaija.com 
Written by : Jasper Ginn | Johanna Renz
Date : 25-01-2015
Last modified : 25-01-2015
Please send suggestions/comments to : Jasperginn@hotmail.com | <Jhanna's email>

STILL TO IMPLEMENT:
	(1) range for scraping - possibly date, years etc.
	(2) implement Goose for individual page scraping
	(3) requests instead of mechanize?
	(4) setup log file
	(5) finish virtual machine setup
	(6) check unique observations SQLite
	(7) send dictionaries to SQLite (instead of lists)
'''

# --------------------------------------------------------------------------------

'''
Import modules
'''

# Import os
import os
# BeautifulSoup
from bs4 import BeautifulSoup
# Logging
import logging
# uuid
import uuid
# Mechanize
import mechanize
# requests
import requests
# Import SQLite
import sqlite3 as lite

'''
FUNCTION 1 : create the URLs for the scraper
	Parameters : 
		lower_range : integer
			Low end of the page number (lower == more recent). Should be set at 1
		upper_range : integer
			High end of the page number (higher == less recent).
'''
def pageMaker(lower_range, upper_range):
	pages = range(lower_range,upper_range)
	urls = [ 'http://reclaimnaija.net/reports?page={}'.format(str(p)) 
			 for p in pages ]
	return(urls)

'''
FUNCTION 2 : create the SQLite database and commit headers
	Parameters :
		dbname 	  : string
			name of the database
		tablename : string
			name of the table in which to store results
		path	  : string
			path to store database. Defaults to '/home/vagrant/Documents/'
'''

def dbSetup(dbname, tablename, path = '/home/vagrant/Documents/'):
	os.chdir(path)
	con = lite.connect(dbname + '.db')
	cur = con.cursor()
	# send headers and create table
	cur.execute("DROP TABLE IF EXISTS {};".format(tablename))
	cur.execute("CREATE TABLE {}(UniqueId INT, Date TEXT, URL TEXT, Location TEXT, Title TEXT, Report TEXT, Verified TEXT)".format(tablename))
	# Commit
	con.commit()

'''
FUNCTION 3 : Insert results form each page to the database
	Parameters :
		values_list : list 
			list of values to send to the database
		dbname		: string
			name of the database
		tablename	: string
			name of the table in which to store results
		path		: string
			path to the database. Defaults to '/home/vagrant/Documents/'
'''

def dbInsert(values_list, dbname, tablename , path = '/home/vagrant/Documents/'):
	os.chdir(path)
	con = lite.connect(dbname + '.db')  
    with con:  
    	# Cursor file
        cur = con.cursor()
        # Write values to db
        cur.executemany("INSERT INTO {} VALUES(?, ?, ?, ?, ?, ?, ?)".format(tablename), values_list)
        # Commit (i.e. save) changes
        con.commit()
        # Close connection
        con.close()

'''
FUNCTION 4 : Set up the logger file
	Parameters :
		logname : string
			name of the log file
'''

def naijaLogging(logname):
	log_dir =  logname + '.log'
	log_level = 'info'

	logger = logging.getLogger(logname)

	if log_level == 'info':
	    logger.setLevel(logging.INFO)
	elif log_level == 'warning':
	    logger.setLevel(logging.WARNING)
	elif log_level == 'error':
	    logger.setlevel(logging.ERROR)
	elif log_level == 'debug':
	    logger.setlevel(logging.DEBUG)

	if log_dir:
	    fh = logging.FileHandler(log_dir, 'a')
	else:
	    fh = logging.FileHandler( logname + '.log', 'a')
	formatter = logging.Formatter('%(levelname)s; %(asctime)s; %(message)s')
	fh.setFormatter(formatter)

	logger.addHandler(fh)

'''
FUNCTION X : function that captures the index of all urls on each page
	parameters : 
'''

def naijaIndex(url):
	try:
        page = requests.get(url)
        soup = BeautifulSoup(page, "html.parser")
        # Identify the table which holds the values of interest.
	    table = soup.find('div',{'class':'big-block'})
	    # isolate reports
	    try:
		    Naija = table.findAll('div',{'class':'report_row1'})
		    urls = [ N.find('div',{'class':'report_details report_col2'}).find('a').get('href') 
		    		 for N in Naija ]
		    return(urls)
		else:
			print "There was an error while extracting the urls for the individual pages from url {}".format(url) (log)
			return("")
    except:
        print "There was an error while loading the page for url {}. Check the traceback for errors.".format(url) (log)
        return("")

'''
FUNCTION Y : Function that scrapes results from each individual page and stores it in the database
	parameters : 
'''

def naijaScraping(p_url):
	


