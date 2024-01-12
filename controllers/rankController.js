import asyncHandler from 'express-async-handler'
import db from "../connection/connection.js"

export const getBowlingRanks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.bowlingrank,pl.playername,pl.playerpicpath from playerrank as p join player as pl on p.playerid=pl.playerid where p.bowlingrank>0 order by p.bowlingrank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getBattingRanks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.battingrank,pl.playername,pl.playerpicpath from playerrank as p join player as pl on p.playerid=pl.playerid where p.battingrank>0 order by p.battingrank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getRounderRanks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.allrounderrank,pl.playername,pl.playerpicpath from playerrank as p join player as pl on p.playerid=pl.playerid where p.allrounderrank>0 order by p.allrounderrank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getT20Ranks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.t20irank,t.teamname,t.teampicpath from teamrank as p join team as t on p.teamid=t.teamid where t20irank>0 order by t20irank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getOdiRanks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.odirank,t.teamname,t.teampicpath from teamrank as p join team as t on p.teamid=t.teamid where odiirank>0 order by odirank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTestRanks = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select p.testrank,t.teamname,t.teampicpath from teamrank as p join team as t on p.teamid=t.teamid where testrank>0 order by testrank asc");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})

export const updatePlayerRank = asyncHandler(async (req, res) => {
    try {
        const { playerid } = req.params
        let { battingrank, bowlingrank, allrounderrank } = req.body;
        battingrank = Number(battingrank);
        bowlingrank = Number(bowlingrank);
        allrounderrank = Number(allrounderrank);
        let battingrankChaged = false;
        let bowlingrankChanged = false;
        let allrounderrankChanged = false;
        const battingrankBefore = await db.query("select battingrank from playerrank where playerid=$1", [playerid]);
        const bowlingrankBefore = await db.query("select bowlingrank from playerrank where playerid=$1", [playerid]);
        const allrounderrankBefore = await db.query("select allrounderrank from playerrank where playerid=$1", [playerid]);
        if (battingrankBefore.rows[0].battingrank != battingrank) {
            battingrankChaged = true;
        }
        if (bowlingrankBefore.rows[0].bowlingrank != bowlingrank) {
            bowlingrankChanged = true;
        }
        if (allrounderrankBefore.rows[0].allrounderrank != allrounderrank) {
            allrounderrankChanged = true;
        }

        await db.query("update playerrank set battingrank=$1,bowlingrank=$2,allrounderrank=$3 where playerid=$4", [battingrank, bowlingrank, allrounderrank, playerid]);
        // set other ranks i.e decrease rank of player already present at that rank
        // if player is batsman
        if (battingrank > 0 && battingrankChaged) {
            //check if new batting rank is greater than old batting rank , if yes then decrease ranks of other players and if no then increase ranks of other players
            if (battingrank > battingrankBefore.rows[0].battingrank) {
                await db.query("update playerrank set battingrank=battingrank-1 where battingrank<=$1 and battingrank>$2 and playerid!=$3", [battingrank, battingrankBefore.rows[0].battingrank, playerid]);
            } else {
                await db.query("update playerrank set battingrank=battingrank+1 where battingrank>=$1 and battingrank<$2 and playerid!=$3", [battingrank, battingrankBefore.rows[0].battingrank, playerid]);
            }
        }
        // if player is bowler
        if (bowlingrank > 0 && bowlingrankChanged) {
            //check if new bowling rank is greater than old bowling rank , if yes then decrease ranks of other players and if no then increase ranks of other players
            if (bowlingrank > bowlingrankBefore.rows[0].bowlingrank) {
                await db.query("update playerrank set bowlingrank=bowlingrank-1 where bowlingrank<=$1 and bowlingrank>$2 and playerid!=$3", [bowlingrank, bowlingrankBefore.rows[0].bowlingrank, playerid]);
            } else {
                await db.query("update playerrank set bowlingrank=bowlingrank+1 where bowlingrank>=$1 and bowlingrank<$2 and playerid!=$3", [bowlingrank, bowlingrankBefore.rows[0].bowlingrank, playerid]);
            }

            // await db.query("update playerrank set bowlingrank=bowlingrank+1 where bowlingrank>=$1 and playerid!=$2", [bowlingrank, playerid]);
        }
        // if player is allrounder
        if (allrounderrank > 0 && allrounderrankChanged) {
            //check if new allrounder rank is greater than old allrounder rank , if yes then decrease ranks of other players and if no then increase ranks of other players
            if (allrounderrank > allrounderrankBefore.rows[0].allrounderrank) {
                await db.query("update playerrank set allrounderrank=allrounderrank-1 where allrounderrank<=$1 and allrounderrank>$2 and playerid!=$3", [allrounderrank, allrounderrankBefore.rows[0].allrounderrank, playerid]);
            } else {
                await db.query("update playerrank set allrounderrank=allrounderrank+1 where allrounderrank>=$1 and allrounderrank<$2 and playerid!=$3", [allrounderrank, allrounderrankBefore.rows[0].allrounderrank, playerid]);
            }

            // await db.query("update playerrank set allrounderrank=allrounderrank+1 where allrounderrank>=$1 and playerid!=$2", [allrounderrank, playerid]);
        }
        await db.query("update playerrank set battingrank=$1,bowlingrank=$2,allrounderrank=$3 where playerid=$4", [battingrank, bowlingrank, allrounderrank, playerid]);

        // // --write trigger for this
        // create or replace function updatePlayerRank() returns trigger as $$
        // begin
        // if new.battingrank != old.battingrank then
        //     if new.battingrank > old.battingrank then
        //         update playerrank set battingrank = battingrank + 1 where battingrank >= new.battingrank and battingrank < old.battingrank and playerid != old.playerid;
        //     elsif new.battingrank < old.battingrank then
        //         update playerrank set battingrank = battingrank - 1 where battingrank <= new.battingrank and battingrank > old.battingrank and playerid != old.playerid;
        //     end if;
        // end if;
        // if new.bowlingrank != old.bowlingrank then
        //     if new.bowlingrank > old.bowlingrank then
        //         update playerrank set bowlingrank = bowlingrank + 1 where bowlingrank >= new.bowlingrank and bowlingrank < old.bowlingrank and playerid != old.playerid;
        //     elsif new.bowlingrank < old.bowlingrank then
        //         update playerrank set bowlingrank = bowlingrank - 1 where bowlingrank <= new.bowlingrank and bowlingrank > old.bowlingrank and playerid != old.playerid;
        //     end if;
        // end if;
        // if new.allrounderrank != old.allrounderrank then
        //     if new.allrounderrank > old.allrounderrank then
        //         update playerrank set allrounderrank = allrounderrank + 1 where allrounderrank >= new.allrounderrank and allrounderrank < old.allrounderrank and playerid != old.playerid;
        //     elsif new.allrounderrank < old.allrounderrank then
        //         update playerrank set allrounderrank = allrounderrank - 1 where allrounderrank <= new.allrounderrank and allrounderrank > old.allrounderrank and playerid != old.playerid;
        //     end if;
        // end if;
        // return new;
        // end;
        // $$ language plpgsql;

        // create trigger updatePlayerRank after update on playerrank for each row execute procedure updatePlayerRank();

        res.status(200).json({ message: "updated" })
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: error.message })
    }
})
export const updateTeamRank = asyncHandler(async (req, res) => {
    try {
        const { teamid } = req.params
        const { t20irank, odirank, testrank } = req.body;
        let t20irankChanged = false;
        let odirankChanged = false;
        let testrankChanged = false;
        const t20irankBefore = await db.query("select t20irank from teamrank where teamid=$1", [teamid]);
        const odirankBefore = await db.query("select odirank from teamrank where teamid=$1", [teamid]);
        const testrankBefore = await db.query("select testrank from teamrank where teamid=$1", [teamid]);
        if (t20irankBefore.rows[0].t20irank != t20irank) {
            t20irankChanged = true;
        }
        if (odirankBefore.rows[0].odirank != odirank) {
            odirankChanged = true;
        }
        if (testrankBefore.rows[0].testrank != testrank) {
            testrankChanged = true;
        }

        // const result = await db.query("update teamrank set t20irank=$1,odirank=$2,testrank=$3 where teamid=$4", [t20irank, odirank, testrank, teamid]);
        //set other ranks i.e decrease rank of team already present at that rank
        // if team is t20
        if (t20irank > 0 && t20irankChanged) {
            //check if new t20 rank is greater than old t20 rank , if yes then decrease ranks of other teams and if no then increase ranks of other teams
            if (t20irank > t20irankBefore.rows[0].t20irank) {
                await db.query("update teamrank set t20irank=t20irank-1 where t20irank<=$1 and t20irank>$2 and teamid!=$3", [t20irank, t20irankBefore.rows[0].t20irank, teamid]);
            } else {
                await db.query("update teamrank set t20irank=t20irank+1 where t20irank>=$1 and t20irank<$2 and teamid!=$3", [t20irank, t20irankBefore.rows[0].t20irank, teamid]);
            }
            // await db.query("update teamrank set t20irank=t20irank+1 where t20irank>=$1 and teamid!=$2", [t20irank, teamid]);
        }
        // if team is odi    
        if (odirank > 0 && odirankChanged) {
            //check if new odi rank is greater than old odi rank , if yes then decrease ranks of other teams and if no then increase ranks of other teams
            if (odirank > odirankBefore.rows[0].odirank) {
                await db.query("update teamrank set odirank=odirank-1 where odirank<=$1 and odirank>$2 and teamid!=$3", [odirank, odirankBefore.rows[0].odirank, teamid]);
            } else {
                await db.query("update teamrank set odirank=odirank+1 where odirank>=$1 and odirank<$2 and teamid!=$3", [odirank, odirankBefore.rows[0].odirank, teamid]);
            }
            // await db.query("update teamrank set odirank=odirank+1 where odirank>=$1 and teamid!=$2", [odirank, teamid]);
        }
        // if team is test
        if (testrank > 0 && testrankChanged) {
            //check if new test rank is greater than old test rank , if yes then decrease ranks of other teams and if no then increase ranks of other teams
            if (testrank > testrankBefore.rows[0].testrank) {
                await db.query("update teamrank set testrank=testrank-1 where testrank<=$1 and testrank>$2 and teamid!=$3", [testrank, testrankBefore.rows[0].testrank, teamid]);
            } else {
                await db.query("update teamrank set testrank=testrank+1 where testrank>=$1 and testrank<$2 and teamid!=$3", [testrank, testrankBefore.rows[0].testrank, teamid]);
            }
            // await db.query("update teamrank set testrank=testrank+1 where testrank>=$1 and teamid!=$2", [testrank, teamid]);
        }

        await db.query("update teamrank set t20irank=$1,odirank=$2,testrank=$3 where teamid=$4", [t20irank, odirank, testrank, teamid]);

        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})

//get top3 players of each category and top3 teams of each category
export const getTop3Players = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from (select p.playerid,pl.playername,team.teamname,team.teampicpath,pl.playerpicpath,p.battingrank,p.bowlingrank,p.allrounderrank from playerrank as p join player as pl using(playerid) left join team on pl.teamid=team.teamid where p.battingrank>0 order by p.battingrank asc limit 3) as t1 union select * from (select p.playerid,pl.playername,team.teamname,team.teampicpath,pl.playerpicpath,p.battingrank,p.bowlingrank,p.allrounderrank from playerrank as p join player as pl using(playerid) left join team on pl.teamid=team.teamid where p.bowlingrank>0 order by p.bowlingrank asc limit 3) as t2 union select * from (select p.playerid,pl.playername,team.teamname,team.teampicpath,pl.playerpicpath,p.battingrank,p.bowlingrank,p.allrounderrank from playerrank as p join player as pl using(playerid) left join team on pl.teamid=team.teamid where p.allrounderrank>0 order by p.allrounderrank asc limit 3) as t3");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})
export const getTop3Teams = asyncHandler(async (req, res) => {
    try {
        const result = await db.query("select * from (select t.teamid,team.teamname,team.teampicpath,t.t20irank,t.odirank,t.testrank from teamrank as t join team using(teamid) where t.t20irank>0 order by t.t20irank asc limit 3) as t1 union select * from (select t.teamid,team.teamname,team.teampicpath,t.t20irank,t.odirank,t.testrank from teamrank as t join team using(teamid) where t.odirank>0 order by t.odirank asc limit 3) as t2 union select * from (select t.teamid,team.teamname,team.teampicpath,t.t20irank,t.odirank,t.testrank from teamrank as t join team using(teamid) where t.testrank>0 order by t.testrank asc limit 3) as t3");
        res.status(200).json(result.rows)
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
})