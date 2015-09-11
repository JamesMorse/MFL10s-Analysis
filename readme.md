#  Quest for the Optimal Fantasy Football Draft Strategy:  

### Analyzing Results from All 2014 MFL 10s Draft-Only Best Ball Leagues  
*by James Morse* ([@james_morse](https://twitter.com/james_morse))

### Background
In the past few years, draft-only, best ball fantasy football leagues have gained a cult following among serious fantasy players. Combining low $10 entry fees with the draft-only, best ball format makes it easy for one to enter tens (and sometimes hundreds) of leagues to diversify away much of the variance associated with fantasy league results while removing the burden of ongoing management after the draft.  MyFantasyLeague.com was the first to gain traction with these leagues, referred to as "MFL10s" because of the popular $10 entry format.  

### Objective
As the popularity of MFL10s has grown, discussions of the "optimal" draft strategy are commonplace on fantasy football sites and podcasts.  In reading articles on the subject, I had two issues:  

1. **Underlying Data Not Provided**: The data used in these analyses is not made available to the reader to verify the results or analyze further.  

2. **Wrong Metrics**: The analyses tended to focus on the wrong metrics for evaluating success, such as average points scored or average place.  Given that the cash prize pool for the $10 leagues is entirely concentrated in 1st place, the appropriate measure of success is **probability of winning the league**, or better yet, turning that probability into **expected value**.  

### Gathering Data  
Fortunately, MyFantasyLeague.com has a developer API to provide access to their leagues' raw data in JSON and XML formats.  I used an R script to find the MFL10 draft-only, best ball leagues and then pull down the draft pick and final standings data for every team in every applicable league in 2013 and 2014 along with player master data.  Finally, I combined these raw data sets into two Tableau-ready data sets -- one at the team level with columns summarized draft pick data and another at the team draft pick level -- and wrote them to CSV files for Tableau to consume.  The R script is available on from my [GitHub profile](https://github.com/JamesMorse/MFL10s-Analysis).

### Analysis  
My analysis was done using Tableau and is posted on my [Tableau Public profile](https://public.tableau.com/profile/james.morse#!/vizhome/2014MFL10sAnalysis/Insights).