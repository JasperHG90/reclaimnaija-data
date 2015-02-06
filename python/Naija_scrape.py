'''
This script scrapes information about harrassment at the Nigerian 2011 & 2015 elections from www.reclamnaija.com 
Written by : Jasper Ginn & Johanna Renz
Date : 25-01-2015
Last modified : 04-02-2015
Please send suggestions/comments to : Jasperginn@hotmail.com | Johannarenz@hotmail.de

STILL TO IMPLEMENT:
    (1) range for scraping - possibly date, years etc. (low priority)
    (2) Implement function that looks for possible duplicates in SQL database
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
# requests
import requests
# Import SQLite
import sqlite3 as lite
# Import regex
import re
# Import datetime
import datetime
# Import os.path (to check if db exists)
import os.path

'''
+++ MAIN FUNCTIONS +++
'''
    
'''
FUNCTION 1 : function that captures the index of all urls on each page
    parameters : 
        url  :  string
            url of the index page.
'''

def naijaIndex(url):
    page = requests.get(url).text
    soup = BeautifulSoup(page, "html.parser")
    # Identify the table which holds the values of interest.
    table = soup.find('div',{'class':'big-block'})
    # isolate reports
    Naija = table.findAll('div',{'class':'report_row1'})
    urls = [ N.find('div',{'class':'report_details report_col2'}).find('a').get('href') 
            for N in Naija ]
    return(urls)
        
'''
FUNCTION 2 : Function that scrapes results from each individual page and stores it in the database
    parameters : 
        url  :  string
            url pointing towards the individual report
'''

def naijaReport(url):
    soup = BeautifulSoup(requests.get(url).text)
    # Lon / Lat
    try:
        geo = naijaLocs(soup)
        lon = geo[0]
        lat = geo[1]
    except:
        print('GEO: There occurred an error while extracting the geolocations for url {}. Check the log for issues . . . '.format(url))
        lon = ""
        lat = ""
    try:
        # report
        text = ' '.join(soup.find('div',{'class':'report-description'}).find('div',{'class':'content'}).contents[0].split())
    except: 
        print("COMPLAINT: There occurred an error while scraping the report for url {}. Please check the log for issues . . . ".format(url))
        text = ""
    try:
        # Details
        text = ' '.join(soup.find('div',{'class':'report-description'}).find('div',{'class':'content'}).contents[0].split())
        reportD = soup.find('div',{'class':'report-details'})
        # Verified?
        ver = reportD.find('div',{'class':'verified'}).text
        # tag
        tag = reportD.find('h1').text
        # Details
        det = reportD.find('ul',{'class':'details'}).findAll('li')
        Loc = ' '.join(det[0].contents[2].split())
        Dat = datetime.datetime.strptime(' '.join(det[1].contents[2].split()),'%b %d %Y').date()
        Tim = ' '.join(det[2].contents[2].split())
        Cat = ' '.join(det[3].find('a').text.split())
        scrapedate = datetime.date.today()
    except:
        print 'DETAILS: There occurred an error while scraping the details for url {}. Please check the log for issues . . . '.format(url)
        ver = ""
        tag = ""
        Loc = ""
        Dat = ""
        Tim = ""
        Cat = ""
        scrapedate = datetime.date.today()
    # Insert values in db
    vals = [ ( url ,
             str(Dat) ,
             Loc ,
             lon ,
             lat ,
             tag , 
             text ,
             ver ,
             Cat ,
             str(Tim) ,
             str(scrapedate) ) ]
    # Return
    return(vals)

'''
+++ HELPER FUNCTIONS +++
'''

'''
FUNCTION 3 : create the URLs for the scraper
    Parameters : 
        lower_range : integer
            Low end of the page number (lower == more recent). Should be set at 1
        upper_range : integer
            High end of the page number (higher == less recent).
'''

def naijaPages(lower_range, upper_range):
    pages = range(lower_range,upper_range)
    urls = [ 'http://reclaimnaija.net/reports?page={}'.format(str(p)) 
             for p in pages ]
    return(urls)

'''
FUNCTION 4 : create the SQLite database and commit headers
    Parameters :
        dbname    : string
            name of the database
        tablename : string
            name of the table in which to store results
        path  : string
            path to store database. Defaults to '/home/vagrant/Documents/'
'''

def naijadbSetup(dbname, tablename, path = '~/desktop', override = "TRUE"):
    # Want to replace the database?
    if override == 'TRUE':
        pathfile = naijaPathmaker(dbname, path)
        con = lite.connect(pathfile)
        cur = con.cursor()
        # send headers and create table
        cur.execute("DROP TABLE IF EXISTS {};".format(tablename))
        cur.execute("CREATE TABLE {}(URL TEXT, Date TEXT, Location TEXT, Longitude REAL, Latitude REAL, Title TEXT, Report TEXT, Verified TEXT, Category TEXT, Time TEXT, Scrapedate TEXT)".format(tablename))
        # Commit
        con.commit()
    else:
        print "A database with the name {} already exists for path {}. You specified the override option to be {}. The database will be left alone . . . yay!".format(dbname, path, str(override))

'''
FUNCTION 5 : Insert results form each page to the database
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

def naijadbInsert(values_list, dbname, tablename , path = '~/desktop/'):
    pathfile = naijaPathmaker(dbname, path)
    try:
        con = lite.connect(pathfile) 
        with con:  
            # Cursor file
            cur = con.cursor()
            # Write values to db
            cur.executemany("INSERT INTO {} (URL, Date, Location, Longitude, Latitude, Title, Report, Verified, Category, Time , Scrapedate) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);".format(tablename), values_list)
            # Commit (i.e. save) changes
            con.commit()
        # Close connection
        con.close()
            
    except:
        print 'Error while setting up the database. Quitting the script now . . . '
        
'''
FUNCTION 7 : Helper function to retrieve longitude and latitude 
    parameters :
        soup_object  :  A BeautifulSoup instance
            Soup object from the report url
'''

def naijaLocs(soup_object):
    # Found the Lon/Lat combination. Not pretty, but oh well . . . 
    lonlat = re.findall('var myPoint = new OpenLayers.LonLat[(\d)., ]*', string = soup_object.text)[0].strip('var myPoint = new OpenLayers.LonLat')
    lon = lonlat.split(',')[0].strip('( ')
    lat = lonlat.split(',')[1].strip(' )')
    return(float(lon), float(lat))

'''
FUNCTION 8 : Helper function to check if the database already exists. If exists, then don't make a new one (unless you specified to overwrite the database)
    parameters :
        path : string
            path to the database
        tablename : string
            name of the SQLite database
        
'''

def naijadbExists(path, dbname):
    if path.endswith('/'):
        ret = os.path.isfile(path + dbname) 
        return(ret)
    else:
        ret = os.path.isfile(path + '/' + dbname)
        return(ret)
    
'''
FUNCTION 9 : Helper function to check whether a report already exists in the database. Here, we are checking the specific report URL
(which is basically a unique ID) against all report URLs that already exist in the db.
    parameters : 
        url : string
            url of the specific report at reclaimnaija
        dbname : string
            name of the database
        dbtable : string
            table in which reclaimnaija results are stored
        path : string
            system path where the database is stored. Defaults to '~/desktop'
'''

def naijadbCheck(url, dbname, dbtable, path = '~/desktop/'):
    pathsal = naijaPathmaker(dbname, path)
    con = lite.connect(pathsal)
    # Cursor file
    with con:
        cur = con.cursor()
        cur.execute("SELECT URL FROM {} WHERE URL = ?".format(dbtable), (url,))
        data=cur.fetchone()
        if data is None:
            return(None)
        else:
            print('Report for url {} already in database . . . moving on'.format(url))
            return(data[0])
    # Close db connection
    con.close()
    
'''
FUNCTION 10 : Helper function that creates the path for the database. It evaluates whether the path specified by the user ends with
'/'. If yes, then paste. If no, then add the '/' to avoid problems.
    parameters :
        dbname : string
            name of the database
        path : string
            system path where the database is stored. Defaults to '~/desktop'
'''

def naijaPathmaker(dbname, path):
    if path.endswith('/'):
        return(path + dbname + '.db')
    else:
        return(path + '/' + dbname + '.db')

'''
+++ RUN +++
'''

def main(lower_range, upper_range, dbname, tablename, path = "~/desktop/", override = 'FALSE'):
    
    '''
    Set up logger
    '''
    
    log_dir = 'NAIJA.log'
    log_level = 'info'

    logger = logging.getLogger('NAIJA')

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
        fh = logging.FileHandler('backup.log', 'a')
    formatter = logging.Formatter('%(levelname)s; %(asctime)s; %(message)s')
    fh.setFormatter(formatter)

    logger.addHandler(fh)
    
    '''
    Preliminary
    '''
    
    # Check if database exists in given path
    dbE = naijadbExists(path, dbname)
    if dbE == True and override == 'FALSE':
        naijadbSetup(dbname, tablename, path = path, override = override)
    else: 
        # setup the database
        naijadbSetup(dbname, tablename, path = path, override = override)
        print "Successfully set up the database in directory {} with name {}".format(path, dbname)
    
    '''
    Scraping
    '''
    
    # Run naijaPages function
    pages = naijaPages(lower_range, upper_range)
    # For each page, do . . . 
    for page in pages:
        try:
            # Take urls from the index
            indUrls = naijaIndex(page)
        except:
            logger.error("INDEX: There was an error while extracting the urls for the individual pages from url {}.".format(url))
        # For each indexed url, do . . . 
        for url in indUrls:
            print w
            # Check if URL already in database
            res = naijadbCheck(url, dbname, tablename, path = path)
            if res != None and override == "FALSE":
                continue
            else:
                try:
                    vals = naijaReport(url)
                    naijadbInsert(vals, dbname, tablename, path = path)
                except:
                    logger.error('DETAILS: There occurred an error while scraping the details for url {}.'.format(url))

'''
+++ RUN MAIN +++
'''

main(1, 20, 'NAIJA_sec', 'NAIJA_tab', path = '/users/jasper/documents/github.projects/reclaimnaija/data/', override = 'TRUE')