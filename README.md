# eznemo

[![Gem Version](https://badge.fury.io/rb/eznemo.svg)](https://badge.fury.io/rb/eznemo) [![Code Climate](https://codeclimate.com/github/kenjij/eznemo/badges/gpa.svg)](https://codeclimate.com/github/kenjij/eznemo)

A Ruby gem. It's a simple monitoring engine and stores results in a database. Runs on EventMachine.

For reports and alerts, analyze the results in the database.

## Requirements

- Ruby 2.0.0 <=
- eventmachine 1.0 <=

### Data Storage Options

Currently, only support MySQL, so you'll also need the following gem:

- mysql2 0.4 <=

## Getting Started

### Install

```
$ gem install eznemo
```

### Use

```
$ eznemo start -c config.yml
```

### Examples

Config file.

```yaml
---
:probe:
  :name: Probe01
  :logger: 'Logger.new(STDOUT)'
  :log_level: 'Logger::WARN'
:datastore:
  :type: :mysql   # currently the only option
  :queue_size: 20
  :queue_interval: 60   # if present, queue_size will be ignored
  :options:
    :host: 127.0.0.1
    :username: user
    :password: paSsw0rd
    :database: eznemo
:checks:
  :tags:   # multiple tags are AND
    - tag1
    - tag2
:monitor:
  :ping:   # below are all optional
    :path: '/bin/ping'
    :min_interval: 10
    :timeout: 5
    :cmd_opts: '-s 102'
```

## Data Structure

### Checks

```ruby
{
  id: 123,   # auto_increment
  name: 'Check name',
  hostname: '192.168.0.111',
  interval: 60,   # frequecy this check is run in seconds
  type: 'ping',   # or other monitor plugin name
  state: true,   # true means active
  options: '-S 192.168.0.11'
}
```

### Tags

```ruby
{
  check_id: 123,   # from checks
  text: 'prod'   # tag text
}
```

### Results

```ruby
{
  timestamp: '2016-04-01 10:00:00 UTC',
  check_id: 123,   # from checks
  probe: 'Probe01',
  status: true,   # true means OK
  response_ms: 0.012,   # in milliseconds
  status_desc: 'OK'   # short description of the result
}
```


### MySQL

Example using TokuDB.

```sql
CREATE TABLE `checks` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `hostname` varchar(255) NOT NULL DEFAULT '',
  `interval` int(11) NOT NULL COMMENT 'in seconds',
  `type` varchar(255) NOT NULL DEFAULT '',
  `state` tinyint(1) NOT NULL,
  `options` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  CLUSTERING KEY `state` (`state`)
) ENGINE=TokuDB DEFAULT CHARSET=utf8;

CREATE TABLE `tags` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `check_id` int(11) NOT NULL,
  `text` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `check_id` (`check_id`),
  CLUSTERING KEY `text` (`text`)
) ENGINE=TokuDB DEFAULT CHARSET=utf8;

CREATE TABLE `results` (
  `timestamp` datetime NOT NULL COMMENT 'in utc',
  `check_id` int(11) NOT NULL,
  `probe` varchar(255) NOT NULL DEFAULT '',
  `status` tinyint(1) NOT NULL,
  `response_ms` float NOT NULL DEFAULT '0',
  `status_desc` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`timestamp`, `check_id`, `probe`),
  CLUSTERING KEY `check_id` (`check_id`)
) ENGINE=TokuDB DEFAULT CHARSET=utf8;
```