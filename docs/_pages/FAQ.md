---
layout: page
title: Frequently Asked Questions
permalink: /faq
order: 6
headings:
    - title: What even is this?
    - title: OMG I found a bug!
    - title: Hey, there's a feature missing!
    - title: I'd like to contribute...but how?
    - title: How do I compile the documentation?
---

## What even is this?

{{ site.product_name }} is an adapter that allows you to connect Hubot to Slack. In addition to making it easy to run
your Hubot scripts in Slack, it also provides basic mechanisms for using the Slack Web API.

On the other hand, {{ site.product_name }} is _not_ a high-level bot development framework, nor is it, really, the best
way to get started writing a Slack App. If you are interested in building Slack bots for widespread distribution in
JavaScript, maybe you should have a look at [BotKit](https://howdy.ai/botkit/) or [Slapp](https://github.com/BeepBoopHQ/slapp).

## OMG I found a bug!

Well, poop. Take a deep breath, and then let us know by
[opening an issue](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/issues). If you're feeling
particularly ambitious, why not
[submit a bugfix?](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/pulls).

## Hey, there's a feature missing!

There's always something more that could be added! You can
[open an issue](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/issues) to start a discussion around
the feature, that's a good start. If you're feeling particularly ambitious, why not write the feature yourself, and
[submit a PR!](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/pulls). We love feedback and we love
help and we don't bite. Much.

## I'd like to contribute...but how?

What an excellent question. First of all, please have a look at our general
[contributing guidelines](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/blob/master/CONTRIBUTING.md).
We'll wait for you here.

All done? Great! While we're super excited to incorporate your new feature into {{ site.product_name }}, there are a
couple of things we want to make sure you've given thought to.

 * Please write unit tests for your new code. But don't _just_ aim to increase the test coverage, rather, we expect you
    to have written _thoughtful_ tests that ensure your new feature will continue to work as expected, and to help future
    contributors to ensure they don't break it!
 * Please document your new feature. Think about _concrete use cases_ for your feature, and add a section to the
    appropriate document (probably
    "[basic_usage.md](https://github.com/{{ site.github_username }}/{{ site.repo_name }}/blob/master/docs/_pages/basic_usage.md)"),
    including a _complete_ sample program that demonstrates your feature.

Including these two items with your pull request will totally make our day—and, more importantly, your future users' days!

On that note...

## How do I compile the documentation?

If you are editing one of the many markdown files in the `docs` folder, there is nothing you need to do: GitHub will
do the right thing automatically. Hooray!