# eznemo

A Ruby gem. It's a simple monitoring engine and stores results in a database. Runs on EventMachine.

## Requirements

- Ruby 2.0.0 <=
- eventmachine 1.0

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
    :database: 'master'
  :tags:
    - tag1
    - tag2
```