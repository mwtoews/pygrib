"""
Introduction
============

Python module for reading and writing GRIB (editions 1 and 2) files.
GRIB is the World Meterological Organization
U{standard<http://www.wmo.ch/pages/prog/www/WMOCodes/GRIB.html>} 
for distributing gridded data. 
The module is a python interface to the
U{GRIB API<http://www.ecmwf.int/products/data/software/grib_api.html>} C library
from the European Centre for Medium-Range Weather Forecasts
(U{ECMWF<http://www.ecmwf.int>}).

Required
========

- U{Python<http://python.org>} 2.4 or higher.  
- U{numpy<http://sourceforge.net/project/showfiles.php?group_id=1369>}
  N-dimensional array object for python. Version 1.2.1 or higher.
- U{pyproj<http://code.google.com/p/pyproj/>} Python interface to 
  U{PROJ.4<http://trac.osgeo.org/proj>} library for cartographic transformations.
- U{GRIB API<http://www.ecmwf.int/products/data/software/grib_api.html.>} C library
  for encoding and decoding GRIB messages (edition 1 and edition 2).
  Version 1.8.0 or higher required.
  To be fully functional, the GRIB API library requires
  U{Jasper<http://www.ece.uvic.ca/~mdadams/jasper>} or 
  U{OpenJPEG<http://www.openjpeg.org>} for JPEG200 encoding,
  and U{PNG<http://www.libpng.org/pub/png/libpng.html>} for PNG encoding.

Installation
============

 - U{Download<http://code.google.com/p/pygrib/downloads/list>} the source code. 
 - set the environment variables C{$GRIBAPI_DIR}, C{$JASPER_DIR}, C{$OPENJPEG_DIR},
 C{$PNG_DIR} and C{$ZLIB_DIR} so that the include files and libraries for
 GRIB API, Jasper, OpenJPEG, PNG and zlib will be found.  
 For example, the include files for 
 jasper should be found in C{$JASPER_DIR/include}, and the jasper
 library should be found in C{$JASPER_DIR/lib} or C{$JASPER_DIR/lib64}. If any of
 those environment  variables are not set, then the default search paths will be used.  
 If the GRIB API library was compiled without JASPER, PNG or OpenJPEG support, then the 
 corresponding environment variable need not be set.
 - Run 'python setup.py install', as root if necessary.
 - Run 'python test.py' to test your installation.


Example usage
=============

 - from the python interpreter prompt, import the package::
    >>> import pygrib
 - open a GRIB file, create a grib message iterator::
    >>> grbs = pygrib.open('sampledata/flux.grb')  
 - print an inventory of the file::
    >>> for grb in grbs:
    >>>     print grb 
    1:Precipitation rate:kg m**-2 s**-1 (avg):regular_gg:surface:level 0:fcst time 108-120:from 200402291200
    2:Surface pressure:Pa (instant):regular_gg:surface:level 0:fcst time 120:from 200402291200
    3:Maximum temperature:K (instant):regular_gg:heightAboveGround:level 2:fcst time 108-120:from 200402291200
    4:Minimum temperature:K (instant):regular_gg:heightAboveGround:level 2:fcst time 108-120:from 200402291200
 - find the first grib message with a matching name::
    >>> for grb in grbs:
    >>>     if grb['name'] == 'Maximum temperature': break
 - extract the data values using the 'values' key (grb.keys() will return a
   list of the available keys)::
    # The data is returned as a numpy array, or if missing values or a bitmap
    # are present, a numpy masked array.  Reduced lat/lon or gaussian grid
    # data is automatically expanded to a regular grid.
    >>> maxt = grb['values']
    >>> print maxt.shape, maxt.min(), maxt.max()
    (94, 192) 223.7 319.9
 - get the latitudes and longitudes of the grid::
    >>> lats, lons = grb.latlons()
    >>> print lats.shape, lats.min(), lats.max(), lons.shape, lons.min(), lons.max()
    (94, 192) -88.5419501373 88.5419501373  0.0 358.125
 - get the second grib message::
    >>> grb = grbs.message(2)
    >>> print grb
    2:Surface pressure:Pa (instant):regular_gg:surface:level 0:fcst time 120:from 200402291200
 - modify the values associated with existing keys::
    >>> grb['forecast_time'] = 240
    >>> grb['dataDate'] = 20100101
 - get the binary string associated with the coded message::
    >>> msg = grb.tostring()
 - write the modified message to a new GRIB file::
    >>> grbout = open('test.grb','wb')
    >>> grbout.write(msg)
    >>> grbout.close()
    >>> grbs = pygrib.open('test.grb')
    >>> grbs.next()
    >>> print grb
    1:Surface pressure:Pa (instant):regular_gg:surface:level 0:fcst time 240:from 201001011200

Documentation
=============

 - see below for the full python API documentation.
  
Changelog
=========

 - B{1.0}: fixed docs, formatting in gribmessage __repr__.
 - B{1.0b1}: added ability to modify existing grib messages with
   __setitem__, get coded binary string with tostring method.
 - B{1.0a1}: initial release. Read-only support nearly
   complete, but no support for writing.

@author: Jeffrey Whitaker.

@contact: U{Jeff Whitaker<mailto:jeffrey.s.whitaker@noaa.gov>}

@version: 1.0

@copyright: copyright 2010 by Jeffrey Whitaker.

@license: Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.
THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, INDIRECT OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE."""
__test__ = None
del __test__ # hack so epydoc doesn't show __test__
__version__ = '1.0'

import numpy as np
from numpy import ma
import pyproj
import_array()

cdef extern from "stdlib.h":
    ctypedef long size_t
    void *malloc(size_t size)
    void free(void *ptr)

cdef extern from "stdio.h":
    ctypedef struct FILE
    FILE *fopen(char *path, char *mode)
    int	fclose(FILE *)
    size_t fwrite(void *ptr, size_t size, size_t nitems, FILE *stream)
    void rewind (FILE *)

cdef extern from "Python.h":
    char * PyString_AsString(object)
    object PyString_FromString(char *s)
    object PyString_FromStringAndSize(char *s, size_t size)

cdef extern from "numpy/arrayobject.h":
    ctypedef int npy_intp 
    ctypedef extern class numpy.ndarray [object PyArrayObject]:
        cdef char *data
        cdef int nd
        cdef npy_intp *dimensions
        cdef npy_intp *strides
        cdef object base
        cdef int flags
    npy_intp PyArray_SIZE(ndarray arr)
    npy_intp PyArray_ISCONTIGUOUS(ndarray arr)
    npy_intp PyArray_ISALIGNED(ndarray arr)
    void import_array()

cdef extern from "grib_api.h":
    ctypedef struct grib_handle
    ctypedef struct grib_keys_iterator
    ctypedef struct grib_context
    cdef enum:
        GRIB_TYPE_UNDEFINED
        GRIB_TYPE_LONG
        GRIB_TYPE_DOUBLE
        GRIB_TYPE_STRING
        GRIB_TYPE_BYTES 
        GRIB_TYPE_SECTION 
        GRIB_TYPE_LABEL 
        GRIB_TYPE_MISSING 
        GRIB_KEYS_ITERATOR_ALL_KEYS            
        GRIB_KEYS_ITERATOR_SKIP_READ_ONLY         
        GRIB_KEYS_ITERATOR_SKIP_OPTIONAL          
        GRIB_KEYS_ITERATOR_SKIP_EDITION_SPECIFIC  
        GRIB_KEYS_ITERATOR_SKIP_CODED             
        GRIB_KEYS_ITERATOR_SKIP_COMPUTED         
        GRIB_KEYS_ITERATOR_SKIP_FUNCTION         
        GRIB_KEYS_ITERATOR_SKIP_DUPLICATES       
        GRIB_MISSING_LONG 
        GRIB_MISSING_DOUBLE
    int grib_get_size(grib_handle *h, char *name, size_t *size)
    int grib_get_native_type(grib_handle *h, char *name, int *type)
    int grib_get_long(grib_handle *h, char *name, long *ival)
    int grib_set_long(grib_handle *h, char *name, long val)
    int grib_get_long_array(grib_handle *h, char *name, long *ival, size_t *size)
    int grib_set_long_array(grib_handle *h, char *name, long *ival, size_t size)
    int grib_get_double(grib_handle *h, char *name, double *dval)
    int grib_set_double(grib_handle *h, char *name, double dval)
    int grib_get_double_array(grib_handle *h, char *name, double *dval, size_t *size)
    int grib_set_double_array(grib_handle *h, char *name, double *dval, size_t size)
    int grib_get_string(grib_handle *h, char *name, char *mesg, size_t *size)
    int grib_set_string(grib_handle *h, char *name, char *mesg, size_t *size)
    grib_keys_iterator* grib_keys_iterator_new(grib_handle* h,unsigned long filter_flags, char* name_space)
    int grib_keys_iterator_next(grib_keys_iterator *kiter)
    char* grib_keys_iterator_get_name(grib_keys_iterator *kiter)
    int grib_handle_delete(grib_handle* h)
    grib_handle* grib_handle_new_from_file(grib_context* c, FILE* f, int* error)        
    char* grib_get_error_message(int code)
    int grib_keys_iterator_delete( grib_keys_iterator* kiter)
    void grib_multi_support_on(grib_context* c)
    void grib_multi_support_off(grib_context* c)
    int grib_get_message(grib_handle* h ,  void** message,size_t *message_length)
    int grib_get_message_copy(grib_handle* h ,  void* message,size_t *message_length)
    long grib_get_api_version()
    int grib_count_in_file(grib_context* c, FILE* f,int* n)


cpdef api_version():
    cdef long api_version
    api_version = grib_get_api_version()
    return api_version

cdef class open(object):
    """ 
    open(filename)
    
    returns iterator object given GRIB filename. When iterated, returns
    instances of the L{gribmessage} class.
     
    @ivar messagesr: The total number of grib messages in the file.

    @ivar messagenumber: The grib message number that the iterator currently
    points to.

    @ivar filename: The GRIB file which the instance represents."""
    cdef FILE *_fd
    cdef grib_handle *_gh
    cdef public object filename, messagenumber, messages
    def __new__(self, filename):
        cdef grib_handle *gh
        cdef FILE *_fd
        cdef int err,nmsgs
        self.filename = filename
        self._fd = fopen(filename, "rb") 
        if self._fd == NULL:
            raise IOError("could not open %s", filename)
        self._gh = NULL
        self.messagenumber = 0
        # turn on support for multi-field grib messages.
        grib_multi_support_on(NULL)
        err = grib_count_in_file(NULL, self._fd, &nmsgs)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        self.messages = nmsgs 
    def __iter__(self):
        return self
    def rewind(self):
        """rewind iterator"""
        cdef grib_handle* gh 
        cdef int err
        rewind(self._fd)
        self._gh = NULL
        self.messagenumber = 0
    def message(self, N):
        """
        message(N)
        
        retrieve N'th message in iterator"""
        cdef int err
        self.rewind()
        for n in range(N):
            err = grib_handle_delete(self._gh)
            if err:
                raise RuntimeError(grib_get_error_message(err))
            self._gh = grib_handle_new_from_file(NULL, self._fd, &err)
            if err:
                raise RuntimeError(grib_get_error_message(err))
            if self._gh == NULL:
                raise IOError('not that many messages in file')
            self.messagenumber = self.messagenumber + 1
        return gribmessage(self)
    def __next__(self):
        cdef grib_handle* gh 
        cdef int err
        err = grib_handle_delete(self._gh)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        self._gh = grib_handle_new_from_file(NULL, self._fd, &err)
        self.messagenumber = self.messagenumber + 1
        if self._gh == NULL and not err:
            raise StopIteration
        if err:
            raise RuntimeError(grib_get_error_message(err))
        return gribmessage(self)
    def close(self):
        """
        close()

        close GRIB file, deallocate C structures associated with class instance"""
        cdef int err
        fclose(self._fd)
        if self._gh != NULL:
            err = grib_handle_delete(self._gh)
            if err:
                raise RuntimeError(grib_get_error_message(err))

cdef class gribmessage(object):
    """
    Grib message returned by GRIB file iterator.
    Grib file iterators are instances of class L{open}.
    Grib messages are dictionary-like objects.

    @ivar messagenumber: The grib message number in the file.

    @ivar projparams: A dictionary containing proj4 key/value pairs describing 
    the grid.  Created when the L{latlons} method is invoked.

    @ivar expand_reduced:  If True (default), reduced lat/lon and gaussian grids
    will be expanded to regular grids when data is accessed via "values" key. If
    False, data is kept on unstructured reduced grid, and is returned in a 1-d
    array.

    @ivar missingvalue_int:  Value given to an integer grib key whose data is
    missing.

    @ivar missingvalue_float:  Value given to an float grib key whose data is
    missing."""
    cdef grib_handle *_gh
    cdef public messagenumber, projparams, missingvalue_int,\
    missingvalue_float, expand_reduced, _ro_keys, _all_keys
    def __new__(self, open grb):
        self._gh = grb._gh
        self.messagenumber = grb.messagenumber
        self.missingvalue_int = GRIB_MISSING_LONG
        self.missingvalue_float = GRIB_MISSING_DOUBLE
        self.expand_reduced = True
        self._all_keys = self.keys()
        self._ro_keys  = self._read_only_keys()
    def __repr__(self):
        """prints a short inventory of the grib message"""
        inventory = []
        inventory.append(
        #repr(self.messagenumber)+':center '+self['centre']+':'+self['name']+':'+self['units'])
        repr(self.messagenumber)+':'+self['name']+':'+self['units'])
        if self.has_key('stepType'):
            inventory.append(' ('+self['stepType']+')')
        inventory.append(':'+self['typeOfGrid'])
        if self.has_key('typeOfLevel'):
            inventory.append(':'+self['typeOfLevel'])
        if self.has_key('topLevel'):
            toplev = self['topLevel']
            botlev = self['bottomLevel']
            if toplev == botlev:
                inventory.append(':level '+repr(toplev))
            else:
                inventory.append(':levels '+repr(self['topLevel'])+\
                '-'+repr(self['bottomLevel']))
        if self.has_key('stepRange'):
            ftime = self['stepRange']
            inventory.append(':fcst time '+ftime)
        elif self.has_key('forecastTime'):
            ftime = repr(self['forecastTime'])
            inventory.append(':fcst time '+ftime)
        inventory.append(
        ':from '+repr(self['dataDate'])+'%04i' % self['dataTime'])
        #if self.has_key('validityDate'):
        #    inventory.append(
        #    ':valid '+repr(self['validityDate'])+repr(self['validityTime']))
        if self.has_key('perturbationNumber'):
            inventory.append(":ens mem %d of %d" %\
            (self['perturbationNumber'],self['numberOfForecastsInEnsemble']))
        return ''.join(inventory)
    def keys(self):
        """
        keys()

        return keys associated with a grib message (a dictionary-like object)
        """
        cdef grib_keys_iterator* gi
        cdef int err, type
        cdef char *name
        # use cached keys if they exist.
        if self._all_keys is not None: return self._all_keys
        # if not, get keys from grib file.
        gi = grib_keys_iterator_new(self._gh,\
                GRIB_KEYS_ITERATOR_ALL_KEYS, NULL)
        keys = []
        while grib_keys_iterator_next(gi):
            name = grib_keys_iterator_get_name(gi)
            key = PyString_AsString(name)
            # ignore these keys.
            if key in\
            ['zero','one','eight','eleven','false','thousand','file','localDir','7777',
             'oneThousand']:
                continue
            err = grib_get_native_type(self._gh, name, &type)
            if err:
                raise RuntimeError(grib_get_error_message(err))
            # keys with these types are gnored.
            if type not in\
            [GRIB_TYPE_UNDEFINED,GRIB_TYPE_SECTION,GRIB_TYPE_BYTES,GRIB_TYPE_LABEL,GRIB_TYPE_MISSING]:
                keys.append(key)
        err = grib_keys_iterator_delete(gi)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        return keys
    def _read_only_keys(self):
        """
        _read_only_keys()

        return read-only keys associated with a grib message (a dictionary-like object)
        """
        cdef grib_keys_iterator* gi
        cdef int err, type
        cdef char *name
        if self._all_keys is None:
            self._all_keys = self.keys()
        gi = grib_keys_iterator_new(self._gh,\
                GRIB_KEYS_ITERATOR_SKIP_READ_ONLY, NULL)
        keys_noro = []
        while grib_keys_iterator_next(gi):
            name = grib_keys_iterator_get_name(gi)
            key = PyString_AsString(name)
            keys_noro.append(key)
        err = grib_keys_iterator_delete(gi)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        keys_ro = []
        for key in self._all_keys:
            if key not in keys_noro:
                keys_ro.append(key)
        return keys_ro
    def __setitem__(self, key, value):
        """
        change values associated with existing grib keys.
        """
        cdef int err, type
        cdef size_t size
        cdef char *name
        cdef long longval
        cdef double doubleval
        cdef ndarray datarr
        cdef char *strdata
        if key in self._ro_keys:
            raise KeyError('key "%s" is read only' % key)
        if key not in self._all_keys:
            raise KeyError('can only modify existing grib keys (key "%s" not found)'
                    % key )
        name = PyString_AsString(key)
        err = grib_get_native_type(self._gh, name, &type)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        elif type == GRIB_TYPE_LONG:
            # is value an array or a scalar?
            datarr = np.asarray(value, np.int)
            is_array == False
            if datarr.shape:
                is_array = True
            if not is_array: # scalar
                longval = value
                err = grib_set_long(self._gh, name, longval)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
            else:
                if key == 'values':
                    datarr = self._unshape_mask(datarr)
                if not PyArray_ISCONTIGUOUS(datarr):
                    datarr = datarr.copy()
                size = datarr.size
                err = grib_set_long_array(self._gh, name, <long *>datarr.data, size)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
        elif type == GRIB_TYPE_DOUBLE:
            # is value an array or a scalar?
            datarr = np.asarray(value, np.float)
            is_array == False
            if datarr.shape:
                is_array = True
            if not is_array: # scalar
                doubleval = value
                err = grib_set_double(self._gh, name, doubleval)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
            else:
                if key == 'values':
                    datarr = self._unshape_mask(datarr)
                if not PyArray_ISCONTIGUOUS(datarr):
                    datarr = datarr.copy()
                size = datarr.size
                err = grib_set_double_array(self._gh, name, <double *>datarr.data, size)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
        elif type == GRIB_TYPE_STRING:
            size=len(value)
            strdata = PyString_AsString(value)
            err = grib_set_string(self._gh, name, strdata, &size)
            if err:
                raise RuntimeError(grib_get_error_message(err))
        else:
            raise ValueError("unrecognized grib type % d" % type)
    def __getitem__(self, key):
        """
        access values associated with grib keys.
        
        The key "values" will return the data associated with the grib message.
        The data is returned as a numpy array, or if missing values or a bitmap
        are present, a numpy masked array.  Reduced lat/lon or gaussian grid
        data is automatically expanded to a regular grid using linear
        interpolation (nearest neighbor if an adjacent grid point is a missing
        value)."""
        cdef int err, type
        cdef size_t size
        cdef char *name
        cdef long longval
        cdef double doubleval
        cdef ndarray datarr
        cdef char strdata[1024]
        name = PyString_AsString(key)
        err = grib_get_size(self._gh, name, &size)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        #if key.startswith('grib 2 Section'):
        #    sectnum = key.split()[3]
        #    size = int(self['section'+sectnum+'Length'])
        err = grib_get_native_type(self._gh, name, &type)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        if type == GRIB_TYPE_UNDEFINED:
            return None
        elif type == GRIB_TYPE_LONG:
            if size == 1: # scalar
                err = grib_get_long(self._gh, name, &longval)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
                return longval
            else: # array
                if self.has_key('jPointsAreConsecutive') and\
                   self['jPointsAreConsecutive']:
                    storageorder='F'
                else:
                    storageorder='C'
                datarr = np.empty(size, np.int, order=storageorder)
                err = grib_get_long_array(self._gh, name, <long *>datarr.data, &size)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
                if key == 'values':
                    return self._reshape_mask(datarr)
                else:
                    return datarr
        elif type == GRIB_TYPE_DOUBLE:
            if size == 1: # scalar
                err = grib_get_double(self._gh, name, &doubleval)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
                return doubleval
            else: # array
                if self.has_key('jPointsAreConsecutive') and\
                   self['jPointsAreConsecutive']:
                    storageorder='F'
                else:
                    storageorder='C'
                datarr = np.empty(size, np.double, order=storageorder)
                err = grib_get_double_array(self._gh, name, <double *>datarr.data, &size)
                if err:
                    raise RuntimeError(grib_get_error_message(err))
                if key == 'values':
                    return self._reshape_mask(datarr)
                else:
                    return datarr
        elif type == GRIB_TYPE_STRING:
            size=1024 # grib_get_size returns 1 ?
            err = grib_get_string(self._gh, name, strdata, &size)
            if err:
                raise RuntimeError(grib_get_error_message(err))
            msg = PyString_FromString(strdata)
            return msg.rstrip()
        else:
            raise ValueError("unrecognized grib type % d" % type)
    def has_key(self,key):
        """
        has_key(key)

        tests whether a grib message object has a specified key.
        """
        return key in self._all_keys
    def tostring(self):
        """
        tostring()

        return coded grib message in a binary string.
        """
        cdef int err
        cdef size_t size
        cdef void *message
        cdef char *name
        cdef FILE *out
        name = PyString_AsString('values')
        err = grib_get_size(self._gh, name, &size)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        err = grib_get_message(self._gh, &message, &size)
        if err:
            raise RuntimeError(grib_get_error_message(err))
        msg = PyString_FromStringAndSize(<char *>message, size)
        return msg
    def _unshape_mask(self, datarr):
        """private method for reshaping and removing mask to "values" array"""
        if datarr.ndim > 2:
            raise ValueError('array must be 1d or 2d')
        # if array is masked, put in masked values and convert to plain numpy array.
        if hasattr(datarr,'mask'):
            datarr = datarr.filled()
        # raise error is expanded reduced grid array is supplied.
        if self.has_key('typeOfGrid') and self['typeOfGrid'].startswith('reduced'):
            if datarr.ndim != 1:
                raise ValueError("reduced grid data array must be 1d")
        if datarr.ndim == 2:
            # check scan modes for rect grids.
            # rows scan in the -x direction (so flip)
            if not self['jScansPositively']:
                datsave = datarr.copy()
                datarr[::-1,:] = datsave[:,:]
            # columns scan in the -y direction (so flip)
            if self['iScansNegatively']:
                datsave = datarr.copy()
                datarr[:,::-1] = datsave[:,:]
            # adjacent rows scan in opposite direction.
            # (flip every other row)
            if self['alternativeRowScanning']:
                datsave = datarr.copy()
                datarr[1::2,::-1] = datsave[1::2,:]
        return datarr
    def _reshape_mask(self, datarr):
        """private method for reshaping and adding mask to "values" array"""
        cdef double missval
        if datarr.ndim > 2:
            raise ValueError('array must be 1d or 2d')
        if self.has_key('Ni') and self.has_key('Nj'):
            nx = self['Ni']
            ny = self['Nj']
        else: # probably spectral data.
            return datarr
        if ny != GRIB_MISSING_LONG and nx != GRIB_MISSING_LONG:
            datarr.shape = (ny,nx)
        if self.has_key('typeOfGrid') and self['typeOfGrid'].startswith('reduced'):
            if self.has_key('missingValue'):
                missval = self['missingValue']
            else:
                missval = 1.e30
            if self.expand_reduced:
                datarr = _redtoreg(2*ny, self['pl'], datarr, missval)
        # check scan modes for rect grids.
        if datarr.ndim == 2:
           # rows scan in the -x direction (so flip)
           if not self['jScansPositively']:
               datsave = datarr.copy()
               datarr[:,:] = datsave[::-1,:]
           # columns scan in the -y direction (so flip)
           if self['iScansNegatively']:
               datsave = datarr.copy()
               datarr[:,:] = datsave[:,::-1]
           # adjacent rows scan in opposite direction.
           # (flip every other row)
           if self['alternativeRowScanning']:
               datsave = datarr.copy()
               datarr[1::2,:] = datsave[1::2,::-1]
           # if there is a missingValue, and some values missing,
           # create a masked array.
           if self.has_key('missingValue') and self['numberOfMissing']:
               datarr = ma.masked_values(datarr, self['missingValue'])
        return datarr
    def latlons(self):
        """
        latlons()

        compute lats and lons (in degrees) of grid.
        Currently handles reg. lat/lon, global gaussian, mercator, stereographic,
        lambert conformal, albers equal-area, space-view, azimuthal 
        equidistant, reduced gaussian, reduced lat/lon and
        lambert azimuthal equal-area grids.

        @return: C{B{lats},B{lons}}, numpy arrays 
        containing latitudes and longitudes of grid (in degrees).
        """
        projparams = {}

        if self.has_key('scaleFactorOfMajorAxisOfOblateSpheroidEarth'):
            scalea = self['scaleFactorOfMajorAxisOfOblateSpheroidEarth']
            scaleb = self['scaleFactorOfMinorAxisOfOblateSpheroidEarth']
            if scalea and scalea is not self.missingvalue_int:
                scalea = 1000.*np.power(10.0,-scalea)
            else:
                scalea = 1
            if scaleb and scaleb is not self.missingvalue_int:
                scaleb = 1000.*np.power(10.0,-scaleb)
            else:
                scaleb = 1.
        else:
            scalea = 1.
            scaleb = 1.
        if self['shapeOfTheEarth'] == 6:
            projparams['a']=self['radius']
            projparams['b']=self['radius']
        elif self['shapeOfTheEarth'] in [3,7]:
            projparams['a']=self['scaledValueOfMajorAxisOfOblateSpheroidEarth']*scalea
            projparams['b']=self['scaledValueOfMinorAxisOfOblateSpheroidEarth']*scaleb
        elif self['shapeOfTheEarth'] == 2:
            projparams['a']=6378160.0
            projparams['b']=6356775.0 
        elif self['shapeOfTheEarth'] == 1:
            projparams['a']=self['scaledValueOfRadiusOfSphericalEarth']*scalea
            projparams['b']=self['scaledValueOfRadiusOfSphericalEarth']*scaleb
        elif self['shapeOfTheEarth'] == 0:
            projparams['a']=6367470.0
            projparams['b']=6367470.0
        elif self['shapeOfTheEarth'] == 0: # WGS84
            projparams['a']=6378137.0
            projparams['b']=6356752.3142
        elif self['shapeOfTheEarth'] == 8:
            projparams['a']=6371200.0
            projparams['b']=6371200.0
        else:
            raise ValueError('unknown shape of the earth flag')

        if self['typeOfGrid'] in ['regular_gg','regular_ll']: # regular lat/lon grid
            lons = self['distinctLongitudes']
            lats = self['distinctLatitudes']
            lons,lats = np.meshgrid(lons,lats) 
            projparams['proj']='cyl'
        elif self['typeOfGrid'] == 'reduced_gg': # reduced global gaussian grid
            lats = self['distinctLatitudes']
            ny = self['Nj']
            nx = 2*ny
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            lon2 = self['longitudeOfLastGridPointInDegrees']
            lons = np.linspace(lon1,lon2,nx)
            lons,lats = np.meshgrid(lons,lats) 
            projparams['proj']='cyl'
        elif self['typeOfGrid'] == 'reduced_ll': # reduced lat/lon grid
            ny = self['Nj']
            nx = 2*ny
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lat2 = self['latitudeOfLastGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            lon2 = self['longitudeOfLastGridPointInDegrees']
            lons = np.linspace(lon1,lon2,nx)
            lats = np.linspace(lat1,lat2,ny)
            lons,lats = np.meshgrid(lons,lats) 
            projparams['proj']='cyl'
        elif self['typeOfGrid'] == 'polar_stereographic':
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            nx = self['Ni']
            ny = self['Nj']
            dx = self['xDirectionGridLengthInMetres']
            dy = self['yDirectionGridLengthInMetres']
            projparams['proj']='stere'
            projparams['lat_ts']=self['latitudeWhereDxAndDyAreSpecifiedInDegrees']
            if self['projectionCentreFlag'] == 0:
                projparams['lat_0']=90.
            else:
                projparams['lat_0']=-90.
            projparams['lon_0']=self['orientationOfTheGridInDegrees']
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        elif self['typeOfGrid'] == 'lambert':
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            nx = self['Ni']
            ny = self['Nj']
            dx = self['DxInMetres']
            dy = self['DyInMetres']
            projparams['proj']='lcc'
            projparams['lon_0']=self['LoVInDegrees']
            projparams['lat_0']=self['LaDInDegrees']
            projparams['lat_1']=self['Latin1InDegrees']
            projparams['lat_2']=self['Latin2InDegrees']
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        elif self['typeOfGrid'] =='albers':
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            nx = self['Ni']
            ny = self['Nj']
            dx = self['Dx']/1000.
            dy = self['Dy']/1000.
            projparams['proj']='aea'
            scale = float(self['grib2divider'])
            projparams['lon_0']=self['LoV']/scale
            if self['truncateDegrees']:
                projparams['lon_0'] = int(projparams['lon_0'])
            projparams['lat_0']=self['LaD']/scale
            if self['truncateDegrees']:
                projparams['lat_0'] = int(projparams['lat_0'])
            projparams['lat_1']=self['Latin1']/scale
            if self['truncateDegrees']:
                projparams['lat_1'] = int(projparams['lat_1'])
            projparams['lat_2']=self['Latin2']/scale
            if self['truncateDegrees']:
                projparams['lat_2'] = int(projparams['lat_2'])
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        elif self['typeOfGrid'] == 'space_view':
            nx = self['Ni']
            ny = self['Nj']
            projparams['lon_0']=self['longitudeOfSubSatellitePointInDegrees']
            projparams['lat_0']=self['latitudeOfSubSatellitePointInDegrees']
            if projparams['lat_0'] == 0.: # if lat_0 is equator, it's a
                projparams['proj'] = 'geos'
            # general case of 'near-side perspective projection' (untested)
            else:
                if projparams['a'] != projparams['b']:
                    raise ValueError('unsupported grid - earth not a perfect sphere')
                projparams['proj'] = 'nsper'
            scale = float(self['grib2divider'])
            projparams['h'] = projparams['a'] *\
            self['altitudeOfTheCameraFromTheEarthSCenterMeasuredInUnitsOfTheEarth']/scale
            # latitude of horizon on central meridian
            lonmax =\
            90.-(180./np.pi)*np.arcsin(projparams['a']/projparams['h'])
            # longitude of horizon on equator
            latmax =\
            90.-(180./np.pi)*np.arcsin(projparams['b']/projparams['h'])
            # h is measured from surface of earth at equator.
            projparams['h'] = projparams['h']-projparams['a']
            # truncate to nearest thousandth of a degree (to make sure
            # they aren't slightly over the horizon)
            latmax = int(1000*latmax)/1000.
            lonmax = int(1000*lonmax)/1000.
            pj = pyproj.Proj(projparams)
            x1,y1 = pj(0.,latmax); x2,y2 = pj(lonmax,0.)
            width = 2*x2; height = 2*y1
            dx =\
            width/self['apparentDiameterOfEarthInGridLengthsInXDirection']
            dy =\
            height/self['apparentDiameterOfEarthInGridLengthsInYDirection']
            x = dx*np.indices((ny,nx),'f')[1,:,:]
            x = x - 0.5*x.max()
            y = dy*np.indices((ny,nx),'f')[0,:,:]
            y = y - 0.5*y.max()
            lons, lats = pj(x,y,inverse=True)
            # set lons,lats to 1.e30 where undefined
            abslons = np.fabs(lons); abslats = np.fabs(lats)
            lons = np.where(abslons < 1.e20, lons, 1.e30)
            lats = np.where(abslats < 1.e20, lats, 1.e30)
        elif self['typeOfGrid'] == "equatorial_azimuthal_equidistant":
            projparams['lat_0'] = self['standardParallel']/1.e6
            projparams['lon_0'] = self['centralLongitude']/1.e6
            dx = self['Dx']/1.e3
            dy = self['Dy']/1.e3
            projparams['proj'] = 'aeqd'
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        elif self['typeOfGrid'] == "lambert_azimuthal_equal_area":
            projparams['lat_0'] = self['standardParallel']/1.e6
            projparams['lon_0'] = self['centralLongitude']/1.e6
            dx = self['Dx']/1.e3
            dy = self['Dy']/1.e3
            projparams['proj'] = 'laea'
            lat1 = self['latitudeOfFirstGridPointInDegrees']
            lon1 = self['longitudeOfFirstGridPointInDegrees']
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        elif self['typeOfGrid'] == 'mercator':
            scale = float(self['grib2divider'])
            lat1 = self['latitudeOfFirstGridPoint']/scale
            if self['truncateDegrees']:
                lat1 = int(lat1)
            lon1 = self['longitudeOfFirstGridPoint']/scale
            if self['truncateDegrees']:
                lon1 = int(lon1)
            lat2 = self['latitudeOfLastGridPoint']/scale
            if self['truncateDegrees']:
                lat2 = int(lat2)
            lon2 = self['longitudeOfLastGridPoint']/scale
            if self['truncateDegrees']:
                lon2 = int(lon2)
            projparams['lat_ts']=self['latitudeSAtWhichTheMercatorProjectionIntersectsTheEarth']/scale
            projparams['lon_0']=0.5*(lon1+lon2)
            projparams['proj']='merc'
            pj = pyproj.Proj(projparams)
            llcrnrx, llcrnry = pj(lon1,lat1)
            urcrnrx, urcrnry = pj(lon2,lat2)
            nx = self['Ni']
            ny = self['Nj']
            dx = (urcrnrx-llcrnrx)/(nx-1)
            dy = (urcrnry-llcrnry)/(ny-1)
            x = llcrnrx+dx*np.arange(nx)
            y = llcrnry+dy*np.arange(ny)
            x, y = np.meshgrid(x, y)
            lons, lats = pj(x, y, inverse=True)
        else:
            raise ValueError('unsupported grid')
        self.projparams = projparams
        return lats, lons

cdef _redtoreg(int nlons, ndarray lonsperlat, ndarray redgrid, double missval):
# convert data on global reduced gaussian to global
# full gaussian grid using linear interpolation.
    cdef long i, j, n, im, ip, indx, ilons, nlats, npts
    cdef double zxi, zdx, flons
    cdef ndarray reggrid
    cdef double *redgrdptr, *reggrdptr
    cdef long *lonsptr
    nlats = len(lonsperlat)
    npts = len(redgrid)
    reggrid = missval*np.ones((nlats,nlons),np.double)
    # get data buffers and cast to desired type.
    lonsptr = <long *>lonsperlat.data
    redgrdptr = <double *>redgrid.data
    reggrdptr = <double *>reggrid.data
    # iterate over full grid, do linear interpolation.
    n = 0
    indx = 0
    for j from 0 <= j < nlats:
        ilons = lonsptr[j]
        flons = <double>ilons
        for i from 0 <= i < nlons:
            # zxi is the grid index (relative to the reduced grid)
            # of the i'th point on the full grid. 
            zxi = i * flons / nlons # goes from 0 to ilons
            im = <long>zxi
            zdx = zxi - <double>im
            if ilons != 0:
                im = (im + ilons)%ilons
                ip = (im + 1 + ilons)%ilons
                # if one of the nearest values is missing, use nearest
                # neighbor interpolation.
                if redgrdptr[indx+im] == missval or\
                   redgrdptr[indx+ip] == missval: 
                    if zdx < 0.5:
                        reggrdptr[n] = redgrdptr[indx+im]
                    else:
                        reggrdptr[n] = redgrdptr[indx+ip]
                else: # linear interpolation.
                    reggrdptr[n] = redgrdptr[indx+im]*(1.-zdx) +\
                                   redgrdptr[indx+ip]*zdx
            n = n + 1
        indx = indx + ilons
    return reggrid
