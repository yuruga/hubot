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
#   hubot create pr <user/repo> <to_branch> <from_branch> --
#   hubot create pr <user/repo> #<number> -- issue
#   hubot deploy pr <user/repo> -- develop to master
#
# Notes:
#
# Author:
#   xlune


module.exports = (robot) ->

    github = require("githubot")(robot)

    unless (url_api_base = process.env.HUBOT_GITHUB_API)?
      url_api_base = "https://api.github.com"

    requestSend = (msg, repo, data) ->
        github.handleErrors (response) ->
            msg.send "Failed... #{response.error}"
        github.post "#{url_api_base}/repos/#{repo}/pulls", data, (pulls) ->
            msg.send "Created pull request ##{pulls['number']}. \nlink: #{pulls['html_url']}"
            return
        return

    makeData = (bt, bf) ->
        return {
            "title": "#{bf} to #{bt}",
            "body": "Please pull this in!",
            "head": bf,
            "base": bt
        }

    makeDataByIssue = (bt, bf, issue) ->
        return {
            "issue": issue,
            "head": bf,
            "base": bt
        }

    getGithubRepo = (msg) =>
        user_id = msg.message.user.id
        key = "repo"
        g = robot.brain.data.github or {}
        if g[user_id]?[key]?
            return g[user_id][key]
        return

    robot.respond /create\s+pr\s+(.+)\s+(.+)\s+(.+)/i, (msg)->
        repo = github.qualified_repo msg.match[1]
        branch_to = msg.match[2]
        branch_from = msg.match[3]
        requestSend(msg, repo, makeData(branch_to, branch_from))
        return

    robot.respond /create\s+pr\s+(.+)\s+#([0-9]+)/i, (msg)->
        repo = github.qualified_repo msg.match[1]
        branch_to = "develop"
        branch_from = "feature/##{msg.match[2]}"
        issue = msg.match[2]
        requestSend(msg, repo, makeDataByIssue(branch_to, branch_from, issue))
        return

    robot.respond /create\s+pr\s+#([0-9]+)/i, (msg)->
        repo = getGithubRepo msg
        if repo
            branch_to = "develop"
            branch_from = "feature/##{msg.match[1]}"
            issue = msg.match[1]
            requestSend(msg, repo, makeDataByIssue(branch_to, branch_from, issue))
        else
            msg.send "Github repo not set."
        return

    robot.respond /deploy\s+pr\s+(.+)/i, (msg)->
        repo = github.qualified_repo msg.match[1]
        branch_to = "master"
        branch_from = "develop"
        requestSend(msg, repo, makeData(branch_to, branch_from))
        return