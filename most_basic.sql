select d.id as driver_id,
       t.id as trip_id,
       datediff(minute, started_at, ended_at) as trip_duration,
       t.distance
from driver d
left join trips t on d.id = t.driver_id
