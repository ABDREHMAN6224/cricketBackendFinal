import requests
import smtplib
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import datetime as dt
import json

base_url = "https://www.daraz.pk/catalog/?q=watches&_keyori=ss&from=input&spm=a2a0e.pdp.search.go.172f611eJaZ5zp"
headers={
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36"
}
response = requests.get(
    "https://en.wikipedia.org/wiki/2023_Cricket_World_Cup_squads"
    )

soup=BeautifulSoup(response.content,'html.parser')
# print(soup)   
divs=soup.find_all('table',class_='sortable')
divs=divs[9:10]
teams=soup.find_all('span',class_='mw-headline')
teams=teams[10:11]
# parseTable(divs[0])

#write parse table function such that it take snam efrom <a> tag in th and rest of info from td and creat ea object of player and return it


def getPictureFromPlayerPage(href):
    if(not href):
        return None
    response = requests.get(
    "https://en.wikipedia.org"+href
    )
    soup=BeautifulSoup(response.content,'html.parser')
    divs=soup.find('table',class_='infobox vcard').find('img',class_='mw-file-element')
    # mw-headline
    if(divs):
        return divs.get('src')
    return None
    #find th
    

def parseTableToGetPlayer(table):
    table_rows = table.find_all('tr')
    #find th
    players= []
    for tr in table_rows:
        player={}
        th = tr.find('th')
        td = tr.find_all('td')
        row = [tr.text for tr in td]
        #get href from th
        if(len(row)>6):
            player['dob']=row[1].split('(')[1].split(')')[0]
            player['playertype']=row[3]
            player['bathand']=row[4]
            player['bowlhand']=row[5].split('-')[0]
            player['bowltype']=row[5]
        row.append(th.text)
        a = th.find()
        pic = None
        player['playerpicpath']=""
        if(a):
        #get href from a
            href = a.get('href')
            player['playername']=a.text
            pic = getPictureFromPlayerPage(href)
            player['playerpicpath']="https:"+(pic or "")
        players.append(player)
    return players

parsedData = [parseTableToGetPlayer(div) for div in divs]
parsedData=[{teams[i].text:parsedData[i]} for i in range(len(teams))]
# print(parsedData)
with open('data2.json', 'w') as outfile:
    json.dump(parsedData, outfile)
print(parsedData)
