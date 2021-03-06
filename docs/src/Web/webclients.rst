.. _getdata:

************
Web Requests
************

Data requests use ``get_data!`` for FDSN or IRIS data services; for (near)
real-time streaming, see :ref:`SeedLink<seedlink-section>`.

.. function:: get_data!(S, method, channels; KWs)
.. function:: S = get_data(method, channels; KWs)

| Retrieve time-series data from a web archive to SeisData structure **S**.
|
| **method**
| **"IRIS"**: :ref:`IRISWS timeseries<IRISWS>`.
| **"FDSN"**: :ref:`FDSNWS dataselect<FDSNWS>`. Change FDSN servers with keyword
| ``src`` using the :ref:`server list<servers>` (see ``?seis_www``).
|
| **channels**
| :ref:`Channels to retrieve<cid>` -- string, string array, or parameter file.
| Type ``?chanspec`` at the Julia prompt for more info.
|
| **KWs**
| Keyword arguments; see also :ref:`SeisIO standard KWs<dkw>` or type ``?SeisIO.KW``.
| Standard keywords: fmt, nd, opts, rad, reg, si, to, v, w, y
| Other keywords:
| ``autoname``: Determine file names from channel ID?
| ``msr``: get instrument responses as MultiStageResonse? (FDSN only)
| ``s``: Start time
| ``t``: Termination (end) time
| ``xf``: XML file name for station XML

Examples
========

1. ``get_data!(S, "FDSN", "UW.SEP..EHZ,UW.SHW..EHZ,UW.HSR..EHZ", "IRIS", t=(-600))``: using FDSNWS, get the last 10 minutes of data from three short-period vertical-component channels at Mt. St. Helens, USA.
2. ``get_data!(S, "IRIS", "CC.PALM..EHN", "IRIS", t=(-120), f="sacbl")``: using IRISWS, fetch the last two minutes of data from component EHN, station PALM (Palmer Lift (Mt. Hood), OR, USA,), network CC (USGS Cascade Volcano Observatory, Vancouver, WA, USA), in bigendian SAC format, and merge into SeisData structure `S`.
3. ``get_data!(S, "FDSN", "CC.TIMB..EHZ", "IRIS", t=(-600), autoname=true)``: using FDSNWS, get the last 10 minutes of data from channel EHZ, station TIMB (Timberline Lodge, OR, USA), save the data directly to disk using an auto-generated filename, and add it to SeisData structure `S` in memory.
4. ``S = get_data("FDSN", "HV.MOKD..HHZ", "IRIS", s="2012-01-01T00:00:00", t=(-3600))``: using FDSNWS, fill a new SeisData structure `S` with an hour of data ending at 2012-01-01, 00:00:00 UTC, from HV.MOKD..HHZ (USGS Hawai'i Volcano Observatory).


FDSN Queries
============

.. _FDSNWS:

`The International Federation of Digital Seismograph Networks (FDSN) <http://www.fdsn.org/>`_ is a global organization that supports seismology research. The FDSN web protocol offers near-real-time access to data from thousands of instruments across the world.

FDSN queries in SeisIO are highly customizable; see :ref:`data keywords list <dkw>` and :ref:`channel id syntax <cid>`.


Data Query
**********
.. function:: get_data!(S, "FDSN", channels; KWs)
   :noindex:
.. function:: S = get_data("FDSN", channels; KWs)
   :noindex:


Station Query
*************
.. function:: FDSNsta!(S, chans, KW)
   :noindex:
.. function:: S = FDSNsta(chans, KW)
   :noindex:

Fill channels `chans` of SeisData structure `S` with information retrieved from
remote station XML files by web query.

| :ref:`Shared keywords<dkw>`: src, to, v
| Other keywords:
| ``s``: Start time
| ``t``: Termination (end) time

Writing to disk and file names
******************************
`autoname=true` attempts to emulate IRISWS channel file naming conventions.
A major changes to request syntax is needed for this to work, however: each
request must return *exactly one* channel.

For example:
* ``get_data("FDSN", "UW.LON..BHZ", autoname=true)`` generates IRIS-style
filenames because the channel name is uniquely specified.
* ``get_data("FDSN", "UW.LON..BH?", autoname=true)`` still writes to disk, but
can't use IRIS-style file names because the request returns three channels.


IRIS Queries
============

.. _IRISWS:

Incorporated Research Institutions for Seismology `(IRIS) <http://www.iris.edu/>`_
is a consortium of universities dedicated to the operation of science facilities
for the acquisition, management, and distribution of seismological data.

Data Query Features
*******************
* Stage zero gains are removed from trace data; all IRIS data will appear to have a gain of 1.0.
* IRISWS disallows wildcards in channel IDs.
* Channel spec *must* include the net, sta, cha fields; thus, CHA = "CC.VALT..BHZ" is OK; CHA = "CC.VALT" is not.
