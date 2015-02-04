'''
This script scrapes information about harrassment at the Nigerian 2011 & 2015 elections from www.reclamnaija.com 
Written by : Jasper Ginn
Date : 25-01-2015
Last modified : 04-02-2015
Please send suggestions/comments to : Jasperginn@hotmail.com | <Jhanna's email>

STILL TO IMPLEMENT:
    (1) range for scraping - possibly date, years etc. (low priority)
    (2) Implement function that looks for possible duplicates in SQL database
    (4) setup log file (medium priority)
    (7) send dictionaries to SQLite (instead of lists) (low priority)
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
        path  : string
            path to store database. Defaults to '/home/vagrant/Documents/'
'''

def dbSetup(dbname, tablename, path = '/home/vagrant/Documents/'):
    os.chdir(path)
    con = lite.connect(dbname + '.db')
    cur = con.cursor()
    # send headers and create table
    cur.execute("DROP TABLE IF EXISTS {};".format(tablename))
    cur.execute("CREATE TABLE {}(URL TEXT, Date TEXT, Location TEXT, Longitude REAL, Latitude REAL, Title TEXT, Report TEXT, Verified TEXT)".format(tablename))
    # Commit
    con.commit()

'''
FUNCTION 3 : Insert results form each page to the database
    Parameters :
        values_list : list 
            list of values to send to the database
        dbname      : string
            name of the database
        tablename   : string
            name of the table in which to store results
        path        : string
            path to the database. Defaults to '/home/vagrant/Documents/'
'''

def dbInsert(values_list, dbname, tablename , path = '/home/vagrant/Documents/'):
    os.chdir(path)
    con = lite.connect(dbname + '.db') 
    try:
        with con:  
            # Cursor file
            cur = con.cursor()
            # Write values to db
            cur.executemany("INSERT INTO {} VALUES(?, ?, ?, ?, ?, ?, ?, ?)".format(tablename), values_list)
            # Commit (i.e. save) changes
            con.commit()
            # Close connection
            con.close()
    except:
        print "SQL: There was a problem while inserting the values into the SQLite database. Check the traceback for errors . . ."
        
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
FUNCTION 5 : function that captures the index of all urls on each page
    parameters : 
        url  :  string
            url of the index page.
'''

def naijaIndex(url):
    try:
        page = requests.get(url).text
        soup = BeautifulSoup(page, "html.parser")
        try:
            # Identify the table which holds the values of interest.
            table = soup.find('div',{'class':'big-block'})
            # isolate reports
            try:
                Naija = table.findAll('div',{'class':'report_row1'})
                urls = [ N.find('div',{'class':'report_details report_col2'}).find('a').get('href') 
                        for N in Naija ]
                return(urls)
            except:
                print "INDEX (1): There was an error while extracting the urls for the individual pages from url {}".format(url)
                return("")
        except:
            print "INDEX (2): There was an error while extracting the table for url {}. Check the traceback for errors.".format(url)
            return("")
    except:
        print "INDEX (3): There was an error while loading the page for url {}. Check the traceback for errors.".format(url)

'''
FUNCTION 6 : Helper function to retrieve longitude and latitude 
    parameters :
        soup_object  :  A BeautifulSoup instance
            Soup object from the report url
'''

def naijaLocs(soup_object):
    try:
        # Found the Lon/Lat combination. Not pretty, but oh well . . . 
        lonlat = re.findall('var myPoint = new OpenLayers.LonLat[(\d)., ]*', string = soup_object.text)[0].strip('var myPoint = new OpenLayers.LonLat')
        lon = lonlat.split(',')[0].strip('( ')
        lat = lonlat.split(',')[1].strip(' )')
        return(float(lon), float(lat))
    except:
        print 'LOCATION: there was an error retrieving the location. Check the log for issues . . . '
        return("", "")
        
'''
FUNCTION 6 : Function that scrapes results from each individual page and stores it in the database
    parameters : 
        url  :  string
            url pointing towards the individual report
'''

def naijaReport(url):
    try:
        soup = BeautifulSoup(requests.get(url).text)
    except:
        print "REPORT: Error loading page with bs4. Check the log for traceback . . . "
        return(url,"","","","","","","")
    # Lon / Lat
    try:
        geo = naijaLocs(soup)
        lon = geo[0]
        lat = geo[0]
    except:
        print 'GEO: There occurred an error while extracting the geolocations. Check the log for issues . . . '
        lon = ""
        lat = ""
    try:
        # report
        text = url.find('div',{'class':'report-description'}).find('div',{'class':'content'}).get_text.strip('\n\t\t\t\t\t\t\t\t\t')
    except: 
        print "COMPLAINT: There occurred an error while scraping the report. Please check the log for issues . . . "
        text = ""
    try:
        # Details
        reportD = soup.find('div',{'class':'report-details'})
        # Verified?
        ver = reportD.find('div',{'class':'verified'}).get_text
        # tag
        tag = reportD.find('h1')
        # Details
        det = reportD.find('ul',{'class':'details'}).findAll('li')
        Loc = det[0].get_text
        Dat = det[1].get_text
        Tim = det[2].get_text
        Cat = det[3].get_text
    except:
        print 'DETAILS: There occurred an error while scraping the details. Please check the log for issues . . . '
        ver = ""
        tag = ""
        Loc = ""
        Dat = ""
        Tim = ""
        Cat = ""
    # Insert values in db
    vals = [ url ,
             Dat ,
             Loc ,
             lon ,
             lat ,
             tag , 
             text ,
             ver ]
    # Return
    return(vals)
    
 