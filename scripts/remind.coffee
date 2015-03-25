# Description:
#     Forgetful? Add reminders
#
# Dependencies:
#     None
#
# Configuration:
#     None
#
# Commands:
#     hubot remind <time> <action> - Set a reminder in <time> to do an <action> <time> is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
#
# Author:
#     whitman

class Reminders
    constructor: (@robot) ->
        @cache = []
        @current_timeout = null

        @robot.brain.on 'loaded', =>
            if @robot.brain.data.reminders
                @cache = @robot.brain.data.reminders
                @queue()

    add: (reminder) ->
        @cache.push reminder
        @cache.sort (a, b) -> a.due - b.due
        @robot.brain.data.reminders = @cache
        @queue()

    removeFirst: ->
        reminder = @cache.shift()
        @robot.brain.data.reminders = @cache
        return reminder

    queue: ->
        clearTimeout @current_timeout if @current_timeout
        if @cache.length > 0
            now = new Date().getTime()
            @removeFirst() until @cache.length is 0 or @cache[0].due > now
            if @cache.length > 0
                trigger = =>
                    reminder = @removeFirst()
                    @robot.reply reminder.msg_envelope, 'Remind: ' + reminder.action
                    @queue()
                # setTimeout uses a 32-bit INT
                extendTimeout = (timeout, callback) ->
                    if timeout > 0x7FFFFFFF
                        @current_timeout = setTimeout ->
                            extendTimeout (timeout - 0x7FFFFFFF), callback
                        , 0x7FFFFFFF
                    else
                        @current_timeout = setTimeout callback, timeout
                extendTimeout @cache[0].due - now, trigger

class Reminder
    constructor: (@msg_envelope, @time, @action, @msg) ->
        if @time.match /((?:\d+)(?:weeks?|w|days?|d|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s))/
            @time.replace(/^\s+|\s+$/g, '')
            periods =
                weeks:
                    value: 0
                    regex: "weeks?|w"
                days:
                    value: 0
                    regex: "days?|d"
                hours:
                    value: 0
                    regex: "hours?|hrs?|h"
                minutes:
                    value: 0
                    regex: "minutes?|mins?|m"
                seconds:
                    value: 0
                    regex: "seconds?|secs?|s"

            for period of periods
                pattern = new RegExp('^.*?([\\d\\.]+)\\s*(?:(?:' + periods[period].regex + ')).*$', 'i')
                matches = pattern.exec(@time)
                periods[period].value = parseInt(matches[1]) if matches

            @due = new Date().getTime()
            @due += ((periods.weeks.value * 604800) + (periods.days.value * 86400) + (periods.hours.value * 3600) + (periods.minutes.value * 60) + periods.seconds.value) * 1000
        else
            matches = @time.match /^(?:(\d{4}\/)?(\d{1,2}\/\d{1,2}))?(?:\s+)?(\d{1,2}\:\d{1,2})$/
            my = matches[1]
            md = matches[2]
            mt = matches[3]
            cd = new Date()
            if not my and not md
                my = "#{cd.getFullYear()}/"
                md = "#{cd.getMonth()+1}/#{cd.getDate()}"
                td = new Date("#{my}#{md} #{mt}")
                if not td.getFullYear()
                    msg.send 'Invalid date and time.'
                    return false
                else if td.getTime() < cd.getTime()
                    td = new Date(td.getTime() + 60 * 60 * 24 * 1000)
            else if not my
                cy = "#{cd.getFullYear()}/#{md} #{mt}"
                ny = "#{cd.getFullYear()+1}/#{md} #{mt}"
                td = new Date(cy)
                if not td.getFullYear()
                    msg.send 'Invalid date and time.'
                    return false
                else if td.getTime() < cd.getTime()
                    td = new Date(ny)
            else
                td = new Date("#{my}/#{md} #{mt}")
                if not td.getFullYear()
                    msg.send 'Invalid date and time.'
                    return false
                else if td.getTime() < cd.getTime()
                    msg.send 'You can not specify earlier than the current.'
                    return false
            @due = td.getTime()

    dueDate: ->
        dueDate = new Date @due
        return "#{dueDate.getFullYear()}/#{dueDate.getMonth()+1}/#{dueDate.getDate()} #{dueDate.getHours()}:#{dueDate.getMinutes()}:#{dueDate.getSeconds()}"
        # dueDate.toLocaleString()

module.exports = (robot) ->

    reminders = new Reminders robot

    robot.respond /remind(?:\s+)((?:\d+)(?:weeks?|w|days?|d|hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)|(?:(?:(?:\d{4}\/)?\d{1,2}\/\d{1,2}(?:\s+))?\d{1,2}\:\d{1,2}))(?:\s+)(.*)/i, (msg) ->
        time = msg.match[1]
        action = msg.match[2]
        reminder = new Reminder msg.envelope, time, action, msg
        reminders.add reminder
        msg.send 'SetRemind: ' + action + ' on ' + reminder.dueDate()
