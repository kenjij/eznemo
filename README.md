# eznemo

A Ruby gem. It's a simple monitoring engine and stores results in a database. Runs on EventMachine.

## Requirements

- Ruby 2.0.0 <=
- eventmachine 1.0 <=

### Data Storage Options

Currently, only support MySQL, so you'll need the following gem:

- mysql2 0.4 <=

## Getting Started

### Install

```
$ gem install eznemo
```

### Use

```ruby
$ eznemo start -c config.yml
```

### Examples

Config file.

```yaml
---
:datastore:
  :type: :mysql
  :options:
    :host: '127.0.0.1'
    :username: 'user'
    :password: 'paSsw0rd'
    :database: 'eznemo'
  :tags:
    - tag1
    - tag2
```

## Data Structure

### Checks

```ruby
{
  id: 123, # auto_increment
  name: "Check name",
  hostname: "IP address or hostname",
  interval: 60, # frequecy this check is run in seconds
  type: "ping; or other monitor plugin name",
  state: true, # true means active
  tags: "["tag1", "tag2"]",
  options: "-S 192.168.0.11"
}
```

### Results

```ruby
{
  check_id: 123, # from checks
  timestamp: '2016-04-01 10:00:00 -07:00',
  status: true, # true means OK
  response_ms: 0.012, # in milliseconds
  status_desc: "OK; short description of the result"
}
```
