# Data Warehouse Work Sample Solution Chris Geno (chris@chrisgeno.net)

## <a id="toc-table-of-contents"></a> Table of Contents:
------
- [Introduction](#toc-introduction)
- [Assumptions](#toc-assumptions)
- [Initial Basic Measures We Want to Track and their schema](#toc-initial-solution)
- [A Step Further](#toc-a-step-further)
- [ETL Processes and Infrastructure](#toc-etl-infrastructure)
- [Testing and Debugging](#toc-testing-and-debugging)
- [Afterthoughts](#toc-afterthoughts)

[^back](#toc-table-of-contents)

## <a id="toc-introduction"></a>Introduction:

When considering a data selection problem with an already perfectly structured 2NF schema as provided, my initial thought is to simply denormalize the data at the highest resolution required to minimize join performance hits and provide a basic reporting table. However, taking into account that "we often want to slice and dice these measurements" and we have a variety of types of analysts working with it with varied levels of query skill and tools, a partially denormalized schema that stands up to more performance scrutiny or "weird" tool generated queries and related processes is what I'll create.

[^back](#toc-table-of-contents)

## <a id="toc-assumptions"></a> Assumptions:

* The data in the existing schema is already well formed. IE: dates aren't at impossible times in the future, people aren't a million years old. Essentially I won't check for outlier values with constraints that would obliterate statistics. 
* Updates to important dimensions are relatively infrequent compared to the amount of analysis and ingestion we're doing, like marital status, birthdate, or license state. Basically a heavily real time streaming application with many updates would make me want to approach this with different microservices and kinesis streams feeding tables entirely differently, so I'm abstracting that away.
* Users will have varying levels of skill and toolsets to access this data. IE: I will attempt to optimize for tools like Tableau auto generating weird queries with suboptimal subqueries. Sometimes these tools make bad where clause choices that cause unneeded scans.
* These numbers do not need to be updated in real time. Some data staleness is tolerable so a job of some frequency like hourly or nightly keeps our data sufficiently up to date.
* For simplification, I'll also assume we aren't doing analysis on the app's use itself. IE: the relationship between how often or when a particular object is updated is less important than the actual statistics and dimensions generated through driving activities relevant to insurance rates. We're not looking for how often or why users might be updating their profile across various dimensions.

[^back](#toc-table-of-contents)

## <a id="toc-initial-solution"></a> Initial Basic Measures We Want to Track and a schema, (The oversimplified single query solution we don't want):

Even though this is not what we want. Quickly creating a query that provides a basic denormalized table of the measurements asked for is something I like to do to setup a basic structure to think about. So I'll put that here and then build off of it.

``` sql
select d.id as driver_id,
       t.id as trip_id,
       datediff(minute, started_at, ended_at) as trip_duration,
       t.distance,
       t.started_at as trip_start,
       t.ended_at as trip_end,
from driver d
left join trips t on d.id = t.driver_id
``` 
![image](https://user-images.githubusercontent.com/22456230/122685809-5cca5280-d1d3-11eb-8a31-20a978a02647.png)

With a table generated by this query, we can easily calculate trips taken, trip durations, and miles driven for a driver via query or by letting an analysis tool do the work relatively performantly. From here I'll expand this to add the other dimensions, and handle performance gotchas and optimizations as we go. 

[^back](#toc-table-of-contents)

## <a id="toc-a-step-further"></a> A Step Further:

### Adding in everything else
In looking at the initial schema and thinking about insurance rates for people that drive and what I imagine is the most pertinent dimensions to analyze, I'd guess that we're most frequently going to be looking at drivers and their trips (and hence corresponding tables), secondly dicing those metrics to various vehicles, and very infrequently looking at metrics at a profile level. For this reason, I'm going to denormalize the drivers and trips tables into a performant reporting schema and maintain the vehicles and profiles tables in place. Not eliminating joins altogether, but cutting down on what is likely the most frequent one between our two largest tables and enabling most users to select from a single table and be far more efficient for users using a drag and drop style analysis tool.

In general, I expect to get a lot of datetime filtering in where clauses, and that is one of the first things I like to deal with. Comparing integers tends to be more performant, especially when we have unknown tools being used that might create auto generated sub queries that inadvertently use a string or something that might get interpreted as a string compared to a datetime which can cause unneeded scans. Columns of integers next to each other will make it faster and less likely to get weird and inefficient optimizer behavior from inhumanly or oddly created queries. I would then likely use a compound sort key on these extracted fields. So to our initial construct I'll add the additional dimensions and extract some fields yielding:

![image](https://user-images.githubusercontent.com/22456230/122688091-c94b4e80-d1df-11eb-997f-ad90b6238ff6.png)


At this point I'll point out the need to deal with updates to the original fields should, for example, someones birthdate or marital status change. In large sample sizes subtle changes causing data staleness may not have a noticeable impact but in this case I'll also retain the drivers updated_at field as a check constraint that verifies data consistency in an update job that runs at some frequency to maintain data integrity.

I believe I have a denormalized table encompassing the majority of the fields that will be used. Reducing what is likely the most prominent join and simplifying the primary dataset for analysis. It should be laid out such that a columnar database can filter and calculate on it efficiently despite the queries used to query it. Though some users may need to be encouraged to filter on the integer date part fields since the original datetime values have been left in to ensure no resolution loss or ability to check for edge cases like trips crossing datetime boundaries.

![image](https://user-images.githubusercontent.com/22456230/122688579-b8500c80-d1e2-11eb-827a-8997e022e76d.png)

[^back](#toc-table-of-contents)

## <a id="toc-etl-infrastructure"></a> ETL Processes and Infrastructure:

Now that a schema is layed out some processes would need to be put in place to manage this table. Assuming the size of this data set is far too large to drop and recreate the table each night or update frequency (which I would do with a staging to table rename process if it was possible). We'll want some processes that manage data update and insertion anomalies on some frequency. I've assumed that the volumes we're dealing with here are appropriate to keep the denormalized table in the same redshift instance, and that basic sql processes are viable. We'll have two main processes that run at appropriate TBD intervals in our job that

1. Check for update anomalies to the driver's dimensions between the original table and the current denormalized one, replacing those rows that are out of date
2. Inserting new rows that have been added since the last time the reporting table has been updated.

![image](https://user-images.githubusercontent.com/22456230/122689276-0e26b380-d1e7-11eb-92c4-7001e9b83e76.png)

In other scenarios it may not be appropriate to keep the reporting table in the same Redshift instance due to security or volume issues and we may need to move it to its own instance, or even a different type of warehouse. In this case, I would have the data streams that feed the profile and vehicles tables duplicated to their counterparts in our reporting instance so as not to have to select from them. Then we have a choice of duplicating both the trips and drivers tables in the same manner and performing our ETL in our new instance so as not to have to read from the original database at all, or just running our selects on the original drivers and trips tables and creating our reporting table in the new instance to minimize storage requirement. It may even be appropriate to move this to a schemaless warehouse like DynamoDB with no joins necessary.

[^back](#toc-table-of-contents)

## <a id="toc-testing-and-debugging"></a> Testing and Debugging:

Data verification should be fairly straight forward since we've left vehicles and profiles untouched and done a simple left join.

Some test cases:
1. The number of rows in our new reporting table should be equal to the number in the trips table for a time period <= the denormalized table's creation time. (count(*) from trips = count(*) from drivers_and_trips)
2. Basic driver trip statistics should not have changed at all
``` sql
select d.id as driver_id,
       count(t.id) as num_trips,
       sum(t.distance) as total_distance
from driver d
left join trips t on d.id = t.driver_id
group by 1 order by 1
```       
would be equal to:
``` sql
select driver_id,
       count(trip_id) as num_trips,
       sum(trip_distance) as total_distance
from drivers_and_trips
group by 1 order by 1
```
So a simple EXCEPT query should return no rows for a timestamp <= creation time of the normalized table.


[^back](#toc-table-of-contents)

## <a id="toc-afterthoughts"></a> Afterthoughts:

Should the vehicle dimension dicing have been more important than I initially guessed, it could have just as easily been joined in, with update check constraints placed on those objects as well, but I generally prefer to keep denormalization as simple as possible to mitigate the tradeoffs between load from processes that have to maintain data integrity and space by keeping it to the primary bits of data that will be worked on.

![image](https://user-images.githubusercontent.com/22456230/122796405-f7826a00-d283-11eb-88cf-3e4217968733.png)

A basic query for initial table creation:
``` sql
select d.profile_id,
       d.id as driver_id,
       t.id as trip_id,
       t.vehicle_id,
       date_part(year, t.started_at) as trip_start_year,
       date_part(month, t.started_at) as trip_start_month,
       date_part(day, t.started_at) as trip_start_day,
       date_part(hour, t.started_at) as trip_start_hour,
       datediff(minute, started_at, ended_at) as trip_duration_minutes,
       t.distance as trip_distance,
       t.started_at as trip_start,
       t.ended_at as trip_end,
       birthdate,
       gender,
       marital_status,
       license_state,
       good_student,
       active_military,
       college_graduate,
       d.updated_at as driver_updated_at
from driver d
left join trips t on d.id = t.driver_id
where t.ended_at is not null
``` 
