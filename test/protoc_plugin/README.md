Basic protoc_plugin functionality
=================================

.. _protoc_plugin: empty

Tests to ensure the basic features of `proto_plugin`_ are working.

.. contents::

executable_runfiles_test
------------------------

Checks that the executable of `protoc_plugin`_ has access to its `data` runfiles when the protoc action that generates the outputs is run.