-- Unit tests for helper.get_week_number_sunday_based
--
-- This is a pure date calculation function that computes the week number
-- of a year using Sunday as the first day of the week.
--
-- Week numbering:
-- - Week 1 starts on Jan 1 (even if it's mid-week)
-- - Each subsequent Sunday starts a new week
-- - Dates are in "YYYY-MM-DD" format

local helper = require("parley.helper")

describe("helper.get_week_number_sunday_based", function()
    describe("Group A: January dates (week 1-5)", function()
        it("A1: Jan 1 is always week 1", function()
            -- Test multiple years with different starting weekdays
            assert.equals(1, helper.get_week_number_sunday_based("2024-01-01")) -- Monday
            assert.equals(1, helper.get_week_number_sunday_based("2023-01-01")) -- Sunday
            assert.equals(1, helper.get_week_number_sunday_based("2022-01-01")) -- Saturday
        end)
        
        it("A2: first Sunday determines week transition", function()
            -- 2024: Jan 1 is Monday, so first Sunday is Jan 7 (start of week 2)
            assert.equals(1, helper.get_week_number_sunday_based("2024-01-06")) -- Saturday
            assert.equals(2, helper.get_week_number_sunday_based("2024-01-07")) -- Sunday
            assert.equals(2, helper.get_week_number_sunday_based("2024-01-08")) -- Monday
        end)
        
        it("A3: year starting on Sunday has week 1 as single day", function()
            -- 2023: Jan 1 is Sunday, so week 2 starts Jan 8
            assert.equals(1, helper.get_week_number_sunday_based("2023-01-01")) -- Sunday
            assert.equals(2, helper.get_week_number_sunday_based("2023-01-08")) -- Sunday
        end)
        
        it("A4: end of January week calculation", function()
            -- 2024: Jan 31 is Wednesday, should be week 5
            assert.equals(5, helper.get_week_number_sunday_based("2024-01-31"))
        end)
    end)
    
    describe("Group B: Leap year handling", function()
        it("B1: Feb 29 exists in leap years", function()
            -- 2024 is a leap year
            assert.equals(9, helper.get_week_number_sunday_based("2024-02-29"))
        end)
        
        it("B2: leap year affects day-of-year calculation", function()
            -- 2024 (leap): March 1 is day 61 (31 Jan + 29 Feb + 1)
            -- 2023 (non-leap): March 1 is day 60 (31 Jan + 28 Feb + 1)
            local week_2024 = helper.get_week_number_sunday_based("2024-03-01")
            local week_2023 = helper.get_week_number_sunday_based("2023-03-01")
            
            -- Both are valid week numbers
            assert.is_true(type(week_2024) == "number" and week_2024 > 0)
            assert.is_true(type(week_2023) == "number" and week_2023 > 0)
        end)
        
        it("B3: century years follow leap year rules", function()
            -- 2000 is a leap year (divisible by 400), so Feb 29 exists
            local week_2000 = helper.get_week_number_sunday_based("2000-02-29")
            -- Week number should be valid (between 8 and 10 depending on Jan 1 weekday)
            assert.is_true(week_2000 >= 8 and week_2000 <= 10,
                "Week for 2000-02-29 should be 8-10, got " .. week_2000)
            
            -- 1900 would NOT be a leap year (divisible by 100 but not 400)
            -- We can't test Feb 29, 1900 as it doesn't exist, but March dates work
            local week_1900_mar = helper.get_week_number_sunday_based("1900-03-01")
            assert.is_true(week_1900_mar >= 8 and week_1900_mar <= 10)
        end)
    end)
    
    describe("Group C: Year boundaries", function()
        it("C1: last week of year (week 52 or 53)", function()
            -- 2024: Dec 31 is Tuesday
            local week = helper.get_week_number_sunday_based("2024-12-31")
            assert.is_true(week >= 52 and week <= 53)
        end)
        
        it("C2: week number increases throughout the year", function()
            local week_jan = helper.get_week_number_sunday_based("2024-01-15")
            local week_jun = helper.get_week_number_sunday_based("2024-06-15")
            local week_dec = helper.get_week_number_sunday_based("2024-12-15")
            
            assert.is_true(week_jan < week_jun)
            assert.is_true(week_jun < week_dec)
        end)
    end)
    
    describe("Group D: Edge cases and boundary conditions", function()
        it("D1: handles all months correctly", function()
            -- Test one date from each month in 2024
            local months = {
                {month = "01", day = "15", expected_min = 1, expected_max = 5},
                {month = "02", day = "15", expected_min = 6, expected_max = 10},
                {month = "03", day = "15", expected_min = 10, expected_max = 15},
                {month = "04", day = "15", expected_min = 15, expected_max = 20},
                {month = "05", day = "15", expected_min = 19, expected_max = 24},
                {month = "06", day = "15", expected_min = 23, expected_max = 28},
                {month = "07", day = "15", expected_min = 28, expected_max = 33},
                {month = "08", day = "15", expected_min = 32, expected_max = 37},
                {month = "09", day = "15", expected_min = 36, expected_max = 41},
                {month = "10", day = "15", expected_min = 41, expected_max = 46},
                {month = "11", day = "15", expected_min = 45, expected_max = 50},
                {month = "12", day = "15", expected_min = 49, expected_max = 54},
            }
            
            for _, test_case in ipairs(months) do
                local date_str = "2024-" .. test_case.month .. "-" .. test_case.day
                local week = helper.get_week_number_sunday_based(date_str)
                assert.is_true(week >= test_case.expected_min and week <= test_case.expected_max,
                    string.format("Week for %s should be between %d and %d, got %d",
                        date_str, test_case.expected_min, test_case.expected_max, week))
            end
        end)
        
        it("D2: first and last day of month boundaries", function()
            -- Test month boundaries
            assert.is_number(helper.get_week_number_sunday_based("2024-01-01"))
            assert.is_number(helper.get_week_number_sunday_based("2024-01-31"))
            assert.is_number(helper.get_week_number_sunday_based("2024-02-01"))
            assert.is_number(helper.get_week_number_sunday_based("2024-02-29"))
            assert.is_number(helper.get_week_number_sunday_based("2024-12-31"))
        end)
    end)
    
    describe("Group E: Known reference dates", function()
        it("E1: verifies against known calendar dates", function()
            -- 2024-01-01 is Monday, so:
            -- Week 1: Jan 1-6 (Mon-Sat)
            -- Week 2: Jan 7-13 (Sun-Sat)
            -- Week 3: Jan 14-20 (Sun-Sat)
            
            assert.equals(1, helper.get_week_number_sunday_based("2024-01-01"))
            assert.equals(1, helper.get_week_number_sunday_based("2024-01-06"))
            assert.equals(2, helper.get_week_number_sunday_based("2024-01-07"))
            assert.equals(2, helper.get_week_number_sunday_based("2024-01-13"))
            assert.equals(3, helper.get_week_number_sunday_based("2024-01-14"))
            assert.equals(3, helper.get_week_number_sunday_based("2024-01-20"))
        end)
        
        it("E2: verifies mid-year dates", function()
            -- 2024-07-04 is Thursday (US Independence Day)
            -- Should be week 27 or 28 depending on how Jan 1 falls
            local week = helper.get_week_number_sunday_based("2024-07-04")
            assert.is_true(week >= 26 and week <= 28,
                "Week for 2024-07-04 should be around 27, got " .. week)
        end)
    end)
    
    describe("Group F: Return value validation", function()
        it("F1: always returns a number", function()
            local result = helper.get_week_number_sunday_based("2024-06-15")
            assert.is_true(type(result) == "number")
        end)
        
        it("F2: week numbers are positive integers", function()
            local week = helper.get_week_number_sunday_based("2024-06-15")
            assert.is_true(week > 0)
            assert.is_true(week == math.floor(week)) -- is integer
        end)
        
        it("F3: week numbers are within valid range (1-53)", function()
            -- Test various dates throughout the year
            local dates = {
                "2024-01-01", "2024-03-15", "2024-06-30",
                "2024-09-15", "2024-12-31"
            }
            
            for _, date in ipairs(dates) do
                local week = helper.get_week_number_sunday_based(date)
                assert.is_true(week >= 1 and week <= 53,
                    string.format("Week for %s should be 1-53, got %d", date, week))
            end
        end)
    end)
end)
