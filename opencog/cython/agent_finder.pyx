# Write code for finding and initialising agents in cython because it'll
# probably be simpler
from libcpp cimport bool
from libcpp.vector cimport vector
from cython.operator cimport dereference as deref, preincrement as inc

# basic wrapping for std::string conversion
cdef extern from "<string>" namespace "std":
    cdef cppclass string:
        string()
        string(char *)
        char * c_str()
        int size()

# we need to store module names with modules objects, and which modules 
# agents are from
module_agents = {}

import inspect
def find_subclasses(module, clazz):
    return [ cls for cls in inspect.getmembers(module) \
            if inspect.isclass(cls[1]) and issubclass(cls[1], clazz) ]    

import imp
import opencog.cogserver

cdef extern from "agent_finder_types.h" namespace "opencog":
    cdef struct requests_and_agents_t:
        vector[string] agents
        vector[string] requests

#import signal
#import sys
#def exit_catcher(sig,stack):
    #if sig == signal.SIGINT:
        #print("Caught interrupt signal")
    #sys.exit(sig)
#
#signal.signal(signal.SIGINT, exit_catcher)

cdef api requests_and_agents_t load_module(string& module_name) with gil:
    """ Load module and return a vector of MindAgent names """
    cdef bytes c_str = module_name.c_str()
    cdef requests_and_agents_t results
    try:
        filep,pathname,desc = imp.find_module(c_str)
    except:
        return results
    agent_classes = []
    try:
        the_module = imp.load_module(c_str,filep,pathname,desc)
        # now we need to scan the module for subclasses of MindAgent
        # each entry is a tuple with ("ClassName", <classobject>)
        agent_classes = find_subclasses(the_module,opencog.cogserver.MindAgent)
    finally:
        # Since we may exit via an exception, close fp explicitly.
        if filep: filep.close()
    # convert names into strings
    for a in agent_classes:
        results.agents.push_back(string(a[0]))
    return results

# Initialise an agent of class "agent_name"
cdef api object instantiate_agent(string module_name, string agent_name) with gil:
    cdef bytes module_str = module_name.c_str()
    cdef bytes agent_str = agent_name.c_str()
    cdef requests_and_agents_t results
    print "Instantiating agent " + module_str + "." + agent_str
    agent = None
    try:
        # find and load the module
        filep,pathname,desc = imp.find_module(module_str)
        the_module = imp.load_module(module_str,filep,pathname,desc)
        # get the class object
        agentClass = getattr(the_module, agent_str) 
        # instantiate it
        if agentClass: agent = agentClass()
    except Exception, e:
        print str(e)
    finally:
        # Since we may exit via an exception, close fp explicitly.
        if filep: filep.close()
    return agent

    
