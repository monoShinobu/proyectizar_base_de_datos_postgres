#!/bin/bash


table_actions() {
    case "$1" in
        c) echo "CASCADE";;
        n) echo "SET NULL";;
        r) echo "RESTRICT";;
        a) echo "NO ACTION";;
    esac
}