import requests
import smtplib
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import datetime as dt
import json

driver=webdriver.Chrome()
driver.get("https://www.cricbuzz.com/cricket-series/6732/icc-cricket-world-cup-2023/matches")
driver.implicitly_wait(10)
html_content = driver.page_source
driver.close()
soup = BeautifulSoup(html_content, 'html.parser')
divs=soup.find_all('div',class_='cb-series-matches')

def getBattingData(scorecardTable,matchObj):
    for table in scorecardTable[0:1]:
        item=table.find_all('div',class_='cb-scrd-itms')[0:11]
        for i in item:
            if(not item):
                continue

            row=i.find_all('div')
            if(len(row)<5):
                continue
            playerData={
                "noruns":row[2].text.strip(),
                "nosixes":row[5].text.strip(),
                "nofours":row[4].text.strip(),
                "noballsfaced":row[3].text.strip(),
                "nowickets":0,
                "oversbowled":0,
                "maidenovers":0,
                "runsconceded":0,
                "extras":0,
                "noballs":0,
            }
            matchObj[row[0].text.strip()]=playerData

def getBowlingData(scorecardTable,matchObj):
    for table in scorecardTable[0:1]:
        item=table.find_all('div',class_='cb-scrd-itms')[0:11]
        for i in item:
            if(not item):
                continue
            row=i.find_all('div')
            if(len(row)<5):
                continue
            noruns=0
            nosixes=0
            nofours=0
            noballsfaced=0
            if(row[0].text.strip() in matchObj):
                noruns=matchObj[row[0].text.strip()]["noruns"]
                nosixes=matchObj[row[0].text.strip()]["nosixes"]
                nofours=matchObj[row[0].text.strip()]["nofours"]
                noballsfaced=matchObj[row[0].text.strip()]["noballsfaced"]
            playerData={
                
                "noruns":noruns,
                "nosixes":nosixes,
                "nofours":nofours,
                "noballsfaced":noballsfaced,
                "nowickets":row[4].text,
                "oversbowled":row[1].text,
                "maidenovers":row[2].text,
                "runsconceded":row[3].text,
                "extras":int(row[5].text)+int(row[6].text),
                "noballs":row[5].text,
            }
            matchObj[row[0].text.strip()]=playerData


def getScorecard(href,matchObj):
    if(not href):
        return None
    driver=webdriver.Chrome()
    driver.get("https://www.cricbuzz.com"+href)
    driver.implicitly_wait(10)
    html_content = driver.page_source
    driver.close()
    soup=BeautifulSoup(html_content,'html.parser')
    divs=soup.find('div',id='innings_1')
    innings_2=soup.find('div',id='innings_2')
    # cb-col cb-col-100 cb-ltst-wgt-hdr
    scorecardTable=divs.find_all('div',class_='cb-ltst-wgt-hdr')[0:2]
    scorecardTable2=innings_2.find_all('div',class_='cb-ltst-wgt-hdr')[0:2]
    getBattingData(scorecardTable[0:1],matchObj)
    getBattingData(scorecardTable2[0:1],matchObj)
    getBowlingData(scorecardTable[1:2],matchObj)
    getBowlingData(scorecardTable2[1:2],matchObj)
    # cb-col cb-col-100 cb-scrd-itms
    # mw-headline

def parseDivs(divs):
    matches=[]
    for div in divs:
        date=div.find('div',class_='schedule-date')
        match=div.find('div',class_='cb-srs-mtchs-tm')
        matchtitle=match.find_all('a')[0].text
        team1=matchtitle.split('vs')[0].strip()
        team2=matchtitle.split('vs')[1].strip()
        matchlocation=match.find('div').text
        winner=match.find_all('a')[1].text
        href=match.find_all('a')[1].get('href').split("cricket-scores")[1]
        href="/live-cricket-scorecard"+href
        winnerteam=winner.split('won')[0].strip()
        matchObj={
            "date":date.text,
            "tournamentid":37,
            "team1":team1,
            "team2":team2,
            "winnerteam":winnerteam,
            "location":matchlocation,
            "matchType":"ODI",
            "scorecard":{}
        }
        matches.append(matchObj)
        getScorecard(href,matchObj["scorecard"])
    return matches

matches=parseDivs(divs)
with open('matches.json', 'w') as outfile:
    json.dump(matches, outfile)