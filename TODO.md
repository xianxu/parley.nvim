# TODO

## Notes: use nth week as a folder

Right now, notes are organized based on year/month, two level directory structure. I want to be able to organize with one additional level, which is week. So instead of 2025/04/, it would be 2025/04/W18/. Let's use Sunday as starting of a week, and you can use the following get_week_number_sunday_based as the function to decide the week number. Do verify the implementation. 

```lua
function get_week_number_sunday_based(date_str)
  -- Parse "YYYY-MM-DD" into year, month, day
  local year, month, day = date_str:match("(%d+)%-(%d+)%-(%d+)")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  if not year or not month or not day then
    error("Invalid date format. Expected 'YYYY-MM-DD'")
  end

  -- Convert to time
  local time = os.time{year=year, month=month, day=day}
  local jan1 = os.time{year=year, month=1, day=1}
  local jan1_wday = tonumber(os.date("%w", jan1))  -- 0=Sunday

  -- Sunday on or before Jan 1
  local week1_start = jan1 - jan1_wday * 24 * 60 * 60
  local days_since = math.floor((time - week1_start) / (24 * 60 * 60))
  local week_number = math.floor(days_since / 7) + 1

  return week_number
end
```

Do note that since a week can span two months, for example, W18 will appear in both 2025/04 folder and 2025/05 folder, which is fine. 
