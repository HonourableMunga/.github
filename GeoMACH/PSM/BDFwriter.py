from __future__ import division
import numpy


def writeBDF(filename, nodes, quads, symm, quad_groups, group_names,
             new_mem, new_nodes, new_ucoord, new_vcoord):
    f = open(filename, 'w')

    def writeLine(line):
        write(line,r=80)
        write('\n')

    def write(line,l=0,r=0):
        if l is not 0:
            n = l - len(line)
            for i in range(n):
                line = ' ' + line
        if r is not 0:
            n = r - len(line)
            for i in range(n):
                line = line + ' '
        f.write(line)

    unique = numpy.unique(quad_groups)

    new = numpy.zeros(len(quad_groups), int)
    k = 0
    for i in xrange(1+numpy.max(quad_groups)):
        if numpy.prod(i!=quad_groups) == 0:
            new += k * (i==quad_groups)
            k += 1
    quad_groups[:] = new

    writeLine('$ Generated by ICEMCFD -  NASTRAN Interface Vers.  4.6.1')
    writeLine('$ Nastran input deck')
    writeLine('SOL 103')
    writeLine('CEND')
    writeLine('$')
    writeLine('BEGIN BULK')
    for i in xrange(len(unique)):
        write('$CDSCRPT')
        write(str(i+1), l=16)
        name = group_names[unique[i]]
        write(name+'/'+name[:name.index(':')], l=32)
        write('\n')

    writeLine('$')
    writeLine('$       grid data              0')

    used = numpy.zeros(nodes.shape[0], bool)
    for k in xrange(4):
        used[quads[:,k]-1] = True

    index = 0
    node_indices = numpy.zeros(nodes.shape[0], int)
    for k in xrange(nodes.shape[0]):
        if used[k]:
            index += 1
            node_indices[k] = index

    for k in range(nodes.shape[0]):
        if used[k]:
            write('GRID*   ')
            write(str(node_indices[k]),l=16)
            write('0',l=16)
            write('%.8E' % nodes[k,0],l=16)
            write('%.8E' % nodes[k,1],l=16)
            write('*')
            write(str(node_indices[k]),l=7)
            write('\n')
            write('*')
            write(str(node_indices[k]),l=7)
            write('%.8E' % nodes[k,2],l=16)
            write('0',l=16)
            write(' ',l=16)
            write('0',l=16)
            write(' ',l=8)
            write('\n')            

    for i in range(quads.shape[0]):
        write('CQUAD4  ')
        write(str(i+1),l=8)
        #write(str(quad_groups[i]+1),l=8)
        write(str(i+1),l=8)
        write(str(node_indices[quads[i,0]-1]),l=8)
        write(str(node_indices[quads[i,1]-1]),l=8)
        write(str(node_indices[quads[i,2]-1]),l=8)
        write(str(node_indices[quads[i,3]-1]),l=8)
        write('\n')
        q = quads[i,:]
        if q[0]==q[1] or q[0]==q[2] or q[0]==q[3] or \
           q[1]==q[2] or q[1]==q[3] or q[2]==q[3]:
            print 'invalid quad', q, group_names[quad_groups[i]], quad_groups[i]

        imem = quad_groups[i]
        uv_selector = imem == new_mem
        for k in range(0):#4):
            inode = quads[i,k] - 1
            node = nodes[inode, :]
            candidates = numpy.array(new_nodes)
            for j in range(3):
                candidates[:,j] -= node[j]
            candidates = candidates ** 2
            candidates = numpy.sum(candidates, axis=1)
            candidates += ~uv_selector * 1e16
            imin = numpy.argmin(candidates)
            write('$PARAM'+str(k)+' ')
            write(' ',l=16)
            write('%.8E' % new_ucoord[imin],l=16)
            write('%.8E' % new_vcoord[imin],l=16)
            #write(' ',l=24)
            write('\n')
            

    for i in range(nodes.shape[0]):
        if symm[i] and used[i]:
            write('SPC     ')
            write('1',l=8)
            write(str(node_indices[i]),l=8)
            write('  123456')
            write('     0.0')
            #write(' ',l=40)
            write('\n')

    writeLine('END BULK')

    f.close()