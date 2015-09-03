# LOAD PACKAGES
library(jsonlite)
library(dplyr)
library(data.table)

# CONSTANTS
URL_LEAGUE_SEARCH <- "http://football.myfantasyleague.com/[year]/export?TYPE=leagueSearch&SEARCH=MFL%2010s:%20Draft-Only&JSON=1"
URL_LEAGUE_ROSTERS <- "http://football.myfantasyleague.com/[year]/export?TYPE=rosters&L=[league_id]&JSON=1"
URL_LEAGUE_STANDINGS <- "http://football.myfantasyleague.com/[year]/export?TYPE=leagueStandings&L=[league_id]&JSON=1"
URL_LEAGUE_DRAFT_RESULTS <- "http://football.myfantasyleague.com/[year]/export?TYPE=draftResults&L=[league_id]&JSON=1"
URL_PLAYERS <- "http://football.myfantasyleague.com/[year]/export?TYPE=players&L=&W=&JSON=1"
URL_PLACEHOLDER_YEAR <- "[year]"
URL_PLACEHOLDER_LEAGUE_ID <- "[league_id]"

#*******************************************************************
# HELPER FUNCTIONS TO DOWNLOAD MFL10 LEAGUE DATA 
#  & TRANSFORM INTO DATA TABLES
# [start]
#*******************************************************************
getLeagueResultsByYear <- function (year) {
     # get league IDs for given year
     jsonMFL10LeaguesData <- fromJSON(gsub(URL_PLACEHOLDER_YEAR, year, URL_LEAGUE_SEARCH, fixed = TRUE))
     leagueIDs <- jsonMFL10LeaguesData$leagues$league$id
     
     # get player data for given year
     playerData <- getPlayersByYear(year)
     
     # get league standings for each league 
     leagueStandingsData <- rbindlist(lapply(leagueIDs, getLeagueStandings, year)) %>%
          select(year, league_id, team_id, rank, everything())
     
     # get league draft picks for each league
     leagueDraftData <- rbindlist(lapply(leagueIDs, getLeagueDraftPicks, year)) %>%
          select(year, league_id, team_id, everything()) %>%
          left_join(playerData, by="player_id") %>%
          # clean up messed up position values
          mutate(position = ifelse(position %in% c("Off","XX"), 
                                   "PK",
                                   ifelse(position == "TMDL", 
                                          "Def",
                                          position))) 
     
     # return list with data tables for standings and draft picks
     list(standings = leagueStandingsData,
          draftPicks = leagueDraftData)
}

getPlayersByYear <- function (year) {
     unique_url <- URL_PLAYERS %>%
          gsub(URL_PLACEHOLDER_YEAR, year, ., fixed = TRUE)
     jsonPlayerData <- fromJSON(unique_url)
     playerData <- jsonPlayerData$players$player %>%
          as.data.table() %>%
          mutate(player_id = as.integer(id)) %>%
          select(player_id, player_name = name, team, position)
     playerData
}

getLeagueDraftPicks <- function (league_id, year) {
     unique_url <- URL_LEAGUE_DRAFT_RESULTS %>%
          gsub(URL_PLACEHOLDER_YEAR, year, ., fixed = TRUE) %>%
          gsub(URL_PLACEHOLDER_LEAGUE_ID, league_id, ., fixed = TRUE)
     jsonLeagueDraftData <- fromJSON(unique_url)
     leagueDraftData <- jsonLeagueDraftData$draftResults$draftUnit$draftPick %>%
          as.data.table() %>%
          transmute(year = as.integer(year),
                    league_id = as.integer(league_id),
                    team_id = as.integer(franchise),
                    round = as.integer(round),
                    round_pick = as.integer(pick),
                    player_id = as.integer(player)) %>%
          mutate(overall_pick = (round - 1) * 12 + round_pick)
     #return value
     leagueDraftData
}

getLeagueStandings <- function (league_id, year) {
     unique_standings_url <- URL_LEAGUE_STANDINGS %>%
          gsub(URL_PLACEHOLDER_YEAR, year, ., fixed = TRUE) %>%
          gsub(URL_PLACEHOLDER_LEAGUE_ID, league_id, ., fixed = TRUE)
     jsonLeagueStandingsData <- fromJSON(unique_standings_url)
     standingsData <- jsonLeagueStandingsData$leagueStandings$franchise %>%
          as.data.table() %>%
          transmute(year = as.integer(year),
                    league_id = as.integer(league_id),
                    team_id = as.integer(id),
                    points_scored = as.numeric(pf),
                    power_rank = as.numeric(power_rank),
                    rank = row_number(desc(points_scored))
          ) %>%
          select(year, league_id, team_id, rank, points_scored, power_rank)
     standingsData
}

getLeagueRosters <- function (league_id, year) {
     unique_url <- URL_LEAGUE_ROSTERS %>%
          gsub(URL_PLACEHOLDER_YEAR, year, ., fixed = TRUE) %>%
          gsub(URL_PLACEHOLDER_LEAGUE_ID, league_id, ., fixed = TRUE)
     jsonRostersData <- fromJSON(unique_url)
     rostersList <- jsonRostersData$rosters$franchise
     leagueRostersData <- rbindlist(
          mapply(
               function (teamRosterData, teamId) {
                    mutate(teamRosterData, team_id = as.integer(teamId))
               },
               rostersList$player,
               rostersList$id,
               SIMPLIFY = FALSE)
     ) %>%
          as.data.table() %>%
          transmute(year = as.integer(year),
                    league_id = as.integer(league_id),
                    team_id = team_id,
                    player_id = as.integer(id))
     #return value
     leagueRostersData
}
#*******************************************************************
# HELPER FUNCTIONS TO DOWNLOAD MFL10 LEAGUE DATA 
#  & TRANSFORM INTO DATA TABLES
# [end]
#*******************************************************************

# we'll get data for 2013 & 2014
years <- 2013:2014

leagueResultsList <- lapply(years, getLeagueResultsByYear)
standingsData <- rbindlist(lapply(leagueResultsList, function(x) x[[1]]))
draftPicksData <- rbindlist(lapply(leagueResultsList, function(x) x[[2]]))

# find & exclude data from leagues with the wrong roster size for MFL10s in each year
leagueExclusionData <- draftPicksData %>% 
     group_by(year, league_id) %>% 
     summarize(picks = n()) %>% 
     group_by(year, picks) %>% 
     filter((year == 2013 & picks != 240) | (year == 2014 & picks != 12*22))
standingsData <- anti_join(standingsData, leagueExclusionData, by = c("year", "league_id"))
draftPicksData <- anti_join(draftPicksData, leagueExclusionData, by = c("year", "league_id"))

#draftPicksData %>% filter(year == 2014) %>% group_by(league_id, team_id) %>% summarize(picks = n()) %>% group_by(league_id) %>% summarize(picks = max(picks)) %>% group_by(picks) %>% summarize(league = n())
#draftPicksData %>% filter(year == 2014) %>% group_by(league_id) %>% summarize(picks = n()) %>% filter(picks == 16*12) %>% distinct()

# DATA SET #1: draft pick-level data w/ team's results joined in for reference
draftPicksData <- draftPicksData %>%
     inner_join(standingsData, by=c("year", "league_id", "team_id"))
# save to CSV
write.table(draftPicksData,
            file = sprintf("mfl10_results_draft_pick_level__%s-%s.csv",
                           min(years),
                           max(years)),
            sep = ",",
            row.names = FALSE
)

# DATA SET #2: team-level data w/ results + aggregated info on draft picks including:
# - 1st round pick number
# - counts of players at each position
# - round# position for each round
# - round for first/last player at each position

# part 1: take 1st data set draft picks & summarize to team level 
#  w/ counts & min/max rounds for each position
resultsSummaryData <- draftPicksData %>% 
     group_by(year, league_id, team_id) %>%
     summarize(#keep team level results
               rank = max(rank),
               points_scored = max(points_scored),
               power_rank = max(power_rank),
               round1_pick_num = max(ifelse(round == 1, round_pick, 0)),
               #player counts for each position
               roster_count_qb = sum(ifelse(position == "QB", 1, 0)),
               roster_count_rb = sum(ifelse(position == "RB", 1, 0)),
               roster_count_wr = sum(ifelse(position == "WR", 1, 0)),
               roster_count_te = sum(ifelse(position == "TE", 1, 0)),
               roster_count_def = sum(ifelse(position == "Def", 1, 0)),
               roster_count_pk = sum(ifelse(position == "PK", 1, 0)),
               #get rounds for first selected at each position
               round_first_qb = min(ifelse(position == "QB", round, 99)),
               round_first_rb = min(ifelse(position == "RB", round, 99)),
               round_first_wr = min(ifelse(position == "WR", round, 99)),
               round_first_te = min(ifelse(position == "TE", round, 99)),
               round_first_def = min(ifelse(position == "Def", round, 99)),
               round_first_pk = min(ifelse(position == "PK", round, 99)),
               #get rounds for last selected at each position
               round_last_qb = max(ifelse(position == "QB", round, 99)),
               round_last_rb = max(ifelse(position == "RB", round, 99)),
               round_last_wr = max(ifelse(position == "WR", round, 99)),
               round_last_te = max(ifelse(position == "TE", round, 99)),
               round_last_def = max(ifelse(position == "Def", round, 99)),
               round_last_pk = max(ifelse(position == "PK", round, 99))
     )

# part 2: team-level data set with columns for every round holding positions drafted for each
draft_rounds <- max(draftPicksData$round)
positionByRoundData <- draftPicksData %>% 
     dcast(year + league_id + team_id ~ round,
           value.var = "position")
setnames(positionByRoundData,
         old = 4:(3+draft_rounds),
         new = sprintf("position_round_%s", 1:draft_rounds))

# part 3: team-level data set with columns for every round holding positions drafted for each
early_rounds <- 7
playersByRoundData <- draftPicksData %>% 
     filter(round <= early_rounds) %>%
     dcast(year + league_id + team_id ~ round,
           value.var = "player_name")
setnames(playersByRoundData,
         old = 4:(early_rounds + 3),
         new = sprintf("player_round_%s", 1:early_rounds))

# combine 3 team level data sets into 1
resultsSummaryData <- resultsSummaryData %>%
     inner_join(positionByRoundData, by=c("year", "league_id", "team_id")) %>%
     inner_join(playersByRoundData, by=c("year", "league_id", "team_id"))
     
# write team level data to CSV
write.table(resultsSummaryData,
            file = sprintf("mfl10_results_team_level__%s-%s.csv",
                           min(years),
                           max(years)),
            sep = ",",
            row.names = FALSE
)