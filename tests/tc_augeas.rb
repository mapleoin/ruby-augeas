# -*- coding: utf-8 -*-
##
#  Augeas tests
#
#  Copyright (C) 2011 Red Hat Inc.
#  Copyright (C) 2011 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Authors: David Lutterkort <dlutter@redhat.com>
#          Ionuț Arțăriși <iartarisi@suse.cz>

require 'test/unit'

TOPDIR = File::expand_path(File::join(File::dirname(__FILE__), ".."))

$:.unshift(File::join(TOPDIR, "lib"))
$:.unshift(File::join(TOPDIR, "ext", "augeas"))

require 'augeas'
require 'fileutils'

class TestAugeas < Test::Unit::TestCase

    SRC_ROOT = File::expand_path(File::join(TOPDIR, "tests", "root")) + "/."
    TST_ROOT = File::expand_path(File::join(TOPDIR, "build", "root")) + "/"

    def test_basics
        aug = aug_create(Augeas::SAVE_NEWFILE)
        assert_equal("newfile", aug.get("/augeas/save"))
        assert_equal(TST_ROOT, aug.get("/augeas/root"))

        assert_not_nil(aug.get("/augeas/root"))
        node = "/ruby/test/node"
        assert_nothing_raised {
            aug.set(node, "value")
        }
        assert_equal("value", aug.get(node))
    end

    def test_no_new
        assert_raise NoMethodError do
            Augeas.new
        end
    end

    def test_close
        aug = Augeas::create("/tmp", nil, Augeas::SAVE_NEWFILE)
        assert_equal("newfile", aug.get("/augeas/save"))
        aug.close

        assert_raise(SystemCallError) {
            aug.get("/augeas/save")
        }

        assert_raise(SystemCallError) {
            aug.close
        }
    end

    def test_rm
        aug = aug_create
        aug.set("/foo/bar", "baz")
        assert aug.get("/foo/bar")
        assert_equal 2, aug.rm("/foo")
        assert_nil aug.get("/foo")
    end

    def test_rm_invalid_path
        aug = aug_create
        assert_raises(Augeas::InvalidPathError) { aug.rm('//') }
    end

    def test_set_invalid_path
        aug = aug_create
        assert_raises(Augeas::InvalidPathError) { aug.set("/files/etc//", nil) }
    end

    def test_set_multiple_matches_error
        aug = aug_create
        assert_raises(Augeas::MultipleMatchesError) {
            aug.set("/files/etc/*", nil) }
    end

    def test_set
        aug = aug_create

        aug.set("/files/etc/group/disk/user[last()+1]",["user1", "user2"])
        assert_equal(aug.get("/files/etc/group/disk/user[1]"), "root" )
        assert_equal(aug.get("/files/etc/group/disk/user[2]"), "user1" )
        assert_equal(aug.get("/files/etc/group/disk/user[3]"), "user2" )

        aug.set("/files/etc/group/new_group/user[last()+1]",
                "nuser1", ["nuser2","nuser3"])
        assert_equal(aug.get("/files/etc/group/new_group/user[1]"), "nuser1")
        assert_equal(aug.get("/files/etc/group/new_group/user[2]"), "nuser2" )
        assert_equal(aug.get("/files/etc/group/new_group/user[3]"), "nuser3" )

        aug.rm("/files/etc/group/disk/user")
        aug.set("/files/etc/group/disk/user[last()+1]", "testuser")
        assert_equal(aug.get("/files/etc/group/disk/user"), "testuser")

        aug.rm("/files/etc/group/disk/user")
        aug.set("/files/etc/group/disk/user[last()+1]", nil)
        assert_equal(aug.get("/files/etc/group/disk/user"), nil)
    end

    def test_get_multiple_matches_error
        aug = aug_create

        # Cause an error
        assert_raises (Augeas::MultipleMatchesError) {
            aug.get("/files/etc/hosts/*") }

        err = aug.error
        assert_equal(Augeas::EMMATCH, err[:code])
        assert err[:message]
        assert err[:details]
        assert err[:minor].nil?
    end

    def test_get_invalid_path
        aug = aug_create
        assert_raises (Augeas::InvalidPathError) { aug.get("//") }

        err = aug.error
        assert_equal(Augeas::EPATHX, err[:code])
        assert err[:message]
        assert err[:details]
    end

    def test_srun
        aug = aug_create

        path = "/files/etc/hosts/*[canonical='localhost.localdomain']/ipaddr"
        r, out = aug.srun("get #{path}\n")
        assert_equal(1, r)
        assert_equal("#{path} = 127.0.0.1\n", out)

        assert_equal(0, aug.srun(" ")[0])
        assert_equal(-1, aug.srun("foo")[0])
        assert_equal(-1, aug.srun("set")[0])
        assert_equal(-2, aug.srun("quit")[0])
    end

    private

    def aug_create(flags = Augeas::NONE)
        if File::directory?(TST_ROOT)
            FileUtils::rm_rf(TST_ROOT)
        end
        FileUtils::mkdir_p(TST_ROOT)
        FileUtils::cp_r(SRC_ROOT, TST_ROOT)

        Augeas::create(TST_ROOT, nil, flags)
    end
end
