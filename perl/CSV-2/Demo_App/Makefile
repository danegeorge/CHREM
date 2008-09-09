###
# $Id: Makefile,v 1.3 2001/08/01 02:15:03 christopher Exp $
#
# Distributed under the GNU Lesser General Public License v2.1.  See
# the accompanying lgpl.txt file for the license text; if the file was
# missing you may always obtain a copy from http://www.fsf.org/.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# Copyright (c)2001 Christopher Rath <Christopher@Rath.ca>.
###

all: Business.txt Miscellaneous.txt Personal.txt Untitled.txt NXaddr

Business.txt: AllNames.csv
	./selectFolder Business AllNames.csv >Business.txt

Miscellaneous.txt: AllNames.csv
	./selectFolder Miscellaneous AllNames.csv >Miscellaneous.txt

Personal.txt: AllNames.csv
	./selectFolder Personal AllNames.csv >Personal.txt

Untitled.txt: AllNames.csv
	./selectFolder Untitled AllNames.csv >Untitled.txt

NXaddr:
	$(MAKE) NXclean
	mkdir Business.addresses Miscellaneous.addresses Personal.addresses Untitled.addresses
	./mkNXaddr Business AllNames.csv >Business.addresses/AddressBook.table
	./mkNXaddr Miscellaneous AllNames.csv >Miscellaneous.addresses/AddressBook.table
	./mkNXaddr Personal AllNames.csv >Personal.addresses/AddressBook.table
	./mkNXaddr Untitled AllNames.csv >Untitled.addresses/AddressBook.table

NXclean:
	rm -rf Business.addresses Miscellaneous.addresses Personal.addresses Untitled.addresses
