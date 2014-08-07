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
#   hubot create issue <title> <user/repo>? <github_user>? <milestone_num>? --
#   hubot set github user <user> -- デフォルトで利用するGithubのユーザ名をセット
#   hubot set github repo <repo> -- デフォルトで利用するGithubのリポジトリをセット
#   hubot set github milestone <milestone_num> -- デフォルトで利用するGithubのマイルストーンをセット
#   hubot show github user -- デフォルトで利用するGithubのユーザ名を表示
#   hubot show github repo -- デフォルトで利用するGithubのリポジトリを表示
#   hubot show github milestone --　デフォルトで利用するGithubのマイルストーンを表示
#
# Notes:
#
# Author:
#   xlune

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
    #
    # makeData = (bt, bf) ->
    #     return {
    #         "title": "#{bf} to #{bt}",
    #         "body": "Please pull this in!",
    #         "head": bf,
    #         "base": bt
    #     }
    #
    # makeDataByIssue = (bt, bf, issue) ->
    #     return {
    #         "issue": issue,
    #         "head": bf,
    #         "base": bt
    #     }

    getGithubVer = (key, user_id) =>
        g = robot.brain.data.github or {}
        if g[user_id]?[key]?
            return g[user_id][key]
        return

    robot.respond /set\s+github\s+(.+)\s+(.+)/i, (msg)->
        key = msg.match[1]
        val = msg.match[2]
        if key in GITHUB_VAR_KEYS
            val = github.qualified_repo val if key is "repo"
            if key is "milestone" and not val.match /^[0-9]+$/
                msg.send "Failed. Bad value."
                return
            user_id = msg.message.user.id
            if user_id of robot.brain.data.users
                robot.brain.data.github = {} unless robot.brain.data.github?
                vars = robot.brain.data.github[user_id] or {}
                vars[key] = val
                robot.brain.data.github[user_id] = vars
                robot.brain.save()
                msg.send "Set github value. #{key} is #{val}"
            else
                msg.send "Failed. User Undefined."
        else
            msg.send "Failed. Bad key name."
        return

    robot.respond /show\s+github\s+(.+)/i, (msg)->
        key = msg.match[1]
        if key in GITHUB_VAR_KEYS
            user_id = msg.message.user.id
            if user_id of robot.brain.data.users
                val = getGithubVer(key, user_id)
                if val
                    msg.send "github value. #{key} is #{val}"
                else
                    msg.send "github value. #{key} is Unset..."
            else
                msg.send "Failed. User Undefined."
        else
            msg.send "Failed. Bad key name."
        return

    robot.respond /create\s+issue\s+([^\s]+)(?:\s+([^\s]+))?(?:\s+([^\s]+))?(?:\s+([0-9]+))?/i, (msg)->
        user_id = msg.message.user.id
        title = msg.match[1]
        repo = msg.match[2] or getGithubVer("repo", user_id)
        repo = github.qualified_repo repo if repo
        username = msg.match[3] or getGithubVer("user", user_id)
        milestone = msg.match[4] or getGithubVer("milestone", user_id)
        if title and repo
            data = {}
            data.title = title
            data.assignee = username if username
            data.milestone = milestone if milestone
            requestSend msg, repo, data
        else
            msg.send "create issue failed. "
        return

    # robot.respond /create\s+pr\s+(.+)\s+(.+)\s+(.+)/i, (msg)->
    #     repo = github.qualified_repo msg.match[1]
    #     branch_to = msg.match[2]
    #     branch_from = msg.match[3]
    #     requestSend(msg, repo, makeData(branch_to, branch_from))
    #     return
    #
    # robot.respond /create\s+pr\s+(.+)\s+#([0-9]+)/i, (msg)->
    #     repo = github.qualified_repo msg.match[1]
    #     branch_to = "develop"
    #     branch_from = "feature/##{msg.match[2]}"
    #     issue = msg.match[2]
    #     requestSend(msg, repo, makeDataByIssue(branch_to, branch_from, issue))
    #     return
    #
    # robot.respond /deploy\s+pr\s+(.+)/i, (msg)->
    #     repo = github.qualified_repo msg.match[1]
    #     branch_to = "master"
    #     branch_from = "develop"
    #     requestSend(msg, repo, makeData(branch_to, branch_from))
    #     return
