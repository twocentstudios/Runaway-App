# Runaway App

Runaway App is a Mac OS X app that runs as a daemon and menubar item. It monitors processes for runaway CPU usage above a specified threshold.

## Technical

Runaway app uses the `ps` application via an `NSTask` and parses the results. Therefore, it can't be sandboxed.

## TODOs

[ ] Auto updating
[ ] More intuitive preferences
[ ] List of tasks in menubar item
[ ] Notification links to app

## License

Runaway App is available under the MIT license. See the LICENSE file for more info.

## About

Runaway App was created by [Christopher Trott](http://twitter.com/twocentstudios).
