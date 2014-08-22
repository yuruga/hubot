# Description:
#   create pull requests from a Github repository
#
# Dependencies:
#   "githubot": "0.4.x"
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ORG
#
# Commands:
#   hubot create issue <title> <repo>? <user>? <milestone>?
#   hubot show issues <repo>?
#   hubot set github <key> <value>
#   hubot set github <user> <repo> <milestone>
#   hubot show github <key>?
#
# Notes:
#
# Author:
#   xlune

Util = require "util"

GITHUB_VAR_KEYS = [
    "user"
    "repo"
    "milestone"
]

module.exports = (robot) ->

    github = require("githubot")(robot)

    unless (url_api_base = process.env.HUBOT_GITHUB_API)?
      url_api_base = "https://api.github.com"

    requestSend = (msg, repo, data) ->
        github.handleErrors (response) ->
            msg.send "Failed... #{response.error}"
        github.post "#{url_api_base}/repos/#{repo}/issues", data, (issues) ->
            msg.send "Created issue No.#{issues['number']}. \nlink: #{issues['html_url']}"
            return
        return

    requestShow = (msg, repo, param) ->
        github.handleErrors (response) ->
            msg.send "Failed... #{response.error}"
        github.get "#{url_api_base}/repos/#{repo}/issues", param, (issues) ->
            message = []
            for issue in issues
                message.push "##{issue.number} #{issue.title}"

            if message.length
                msg.send message.join("\n")
            else
                msg.send "Not have issues."
            return
        return

    requestShowMilestone = (msg, repo, param) ->
        github.handleErrors (response) ->
            msg.send "Failed... #{response.error}"
        github.get "#{url_api_base}/repos/#{repo}/milestones", param, (milestones) ->
            message = []
            for milestone in milestones
                message.push "##{milestone.number} #{milestone.title}"

            if message.length
                msg.send message.join("\n")
            else
                msg.send "Not have milestone."
            return
        return

    setGithubVar = (key, val, user_id, room) ->
        robot.brain.data.github = {} unless robot.brain.data.github?
        vars = robot.brain.data.github[user_id] or {}
        vars[room] = vars[room] or {}
        vars[room][key] = val
        robot.brain.data.github[user_id] = vars
        robot.brain.save()
        return

    getGithubVer = (key, user_id, room) ->
        if robot.brain.data.github?[user_id]?[room]?[key]
            return robot.brain.data.github[user_id][room][key]
        return

    robot.respond /set\s+github\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)$/i, (msg)->
        data = {}
        param = {
            user: msg.match[1]
            repo: msg.match[2]
            milestone: msg.match[3]
        }
        user_id = msg.message.user.id
        room = msg.message.room
        for key,val of param
            setGithubVar(key, val, user_id, room)
            data[key] = val
        msg.send "github values.\n#{Util.inspect(data, false, 4)}\nby #{room}"
        return

    robot.respond /set\s+github\s+([^\s]+)\s+([^\s]+)$/i, (msg)->
        key = msg.match[1]
        val = msg.match[2]
        if key in GITHUB_VAR_KEYS
            val = github.qualified_repo val if key is "repo"
            if key is "milestone" and not val.match /^[0-9]+$/
                msg.send "Failed. Bad value."
                return
            user_id = msg.message.user.id
            room = msg.message.room
            if user_id of robot.brain.data.users
                setGithubVar(key, val, user_id, room)
                msg.send "Set github value. #{key} is #{val} by #{room}"
            else
                msg.send "Failed. User Undefined."
        else
            msg.send "Failed. Bad key name."
        return

    robot.respond /show\s+github(?:\s+([^\s]+))?/i, (msg)->
        key = msg.match[1]
        user_id = msg.message.user.id
        room = msg.message.room
        if key in GITHUB_VAR_KEYS
            if user_id of robot.brain.data.users
                val = getGithubVer(key, user_id, room)
                if val
                    msg.send "github value. #{key} is #{val} by #{room}"
                else
                    msg.send "github value. #{key} is Unset..."
            else
                msg.send "Failed. User Undefined."
        else if key
            msg.send "Failed. Bad key name."
        else
            if user_id of robot.brain.data.users
                data = {}
                for key in GITHUB_VAR_KEYS
                    data[key] = getGithubVer(key, user_id, room)
                msg.send "github values.\n#{Util.inspect(data, false, 4)}\nby #{room}"
            else
                msg.send "Failed. User Undefined."
        return

    robot.respond /create\s+issue\s+([^\s]+)(?:\s+([^\s]+))?(?:\s+([^\s]+))?(?:\s+([0-9]+))?/i, (msg)->
        user_id = msg.message.user.id
        room = msg.message.room
        title = msg.match[1]
        repo = msg.match[2] or getGithubVer("repo", user_id, room)
        repo = github.qualified_repo repo if repo
        username = msg.match[3] or getGithubVer("user", user_id, room)
        milestone = msg.match[4] or getGithubVer("milestone", user_id, room)
        if title and repo
            data = {}
            data.title = title
            data.assignee = username if username
            data.milestone = milestone if milestone
            requestSend msg, repo, data
        else
            msg.send "create issue failed. "
        return

    robot.respond /show\s+issues(?:\s+([^\s]+))?/i, (msg) ->
        user_id = msg.message.user.id
        room = msg.message.room
        repo = msg.match[1] or getGithubVer("repo", user_id, room)
        if repo
            param = { state: "open", sort: "created" }
            user_name = getGithubVer("user", user_id, room)
            param.assignee = user_name if user_name?

            requestShow(msg, repo, param)
        else
            msg.send "require repository target."
        return

    robot.respond /show\s+milestones(?:\s+([^\s]+))?/i, (msg) ->
        user_id = msg.message.user.id
        room = msg.message.room
        repo = msg.match[1] or getGithubVer("repo", user_id, room)
        if repo
            param = { state: "open", sort: "created" }
            user_name = getGithubVer("user", user_id, room)
            param.assignee = user_name if user_name?

            requestShowMilestone(msg, repo, param)
        else
            msg.send "require repository target."
        return
