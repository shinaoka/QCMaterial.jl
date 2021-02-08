pushfirst!(PyVector(pyimport("sys")."path"), "") # Add cwd to path
const util = pyimport("util")
const of = pyimport("openfermion")

up_index(i) = 2*(i-1)
down_index(i) = 2*(i-1)+1

"""
Generate single excitations
"""
function gen_t1(a, i)
    #a^\dagger_a a_i (excitation)
    generator = of.ops.FermionOperator((
                    (a, 1),
                    (i, 0)),
                    1.0)
    #-a^\dagger_i a_a (de-exciation)
    generator += of.ops.FermionOperator((
                    (i, 1),
                    (a, 0)),
                    -1.0)
    #JW-transformation of a^\dagger_a a_i - -a^\dagger_i a_a
    util.qulacs_jordan_wigner(generator)
end

"""
Generate pair dobule excitations
"""
function gen_p_t2(aa, ia, ab, ib)
   generator = of.ops.FermionOperator((
        (aa, 1),
        (ab, 1),
        (ib, 0),
        (ia, 0)),
        1.0)
    generator += of.ops.FermionOperator((
        (ia, 1),
        (ib, 1),
        (ab, 0),
        (aa, 0)),
        -1.0)
    util.qulacs_jordan_wigner(generator)
end


"""
Returns UCCSD1 circuit.
"""
function uccsd1(n_qubit, nocc, nvirt)
    theta_offsets = Float64[]
    circuit = qulacs.ParametricQuantumCircuit(n_qubit)
    ioff = 0

    # Singles
    spin_index_functions = [up_index, down_index]
    for (i_t1, (a, i)) in enumerate(Iterators.product(1:nvirt, 1:nocc))
        a_spatial = a + nocc
        i_spatial = i
	for ispin in 1:2
            #Spatial Orbital Indices
            so_index = spin_index_functions[ispin]
            a_spin_orbital = so_index(a_spatial)
            i_spin_orbital = so_index(i_spatial)
            #t1 operator
            qulacs_generator = gen_t1(a_spin_orbital, i_spin_orbital)
            #Add t1 into the circuit
            theta = 0.0
            theta_offsets, ioff = util.add_theta_value_offset(theta_offsets,
                                                      qulacs_generator,
                                                      ioff)
            circuit = util.add_parametric_circuit_using_generator(circuit,
                                                   qulacs_generator,
                                                   theta,i_t1,1.0)
        end
    end


    # Dobules
    for (i_t2, (a, i, b, j)) in enumerate(Iterators.product(1:nvirt, 1:nocc, 1:nvirt, 1:nocc))
            a_spatial = a + nocc
            i_spatial = i
            b_spatial = b + nocc
            j_spatial = j

            #Spatial Orbital Indices
            aa = up_index(a_spatial)
            ia = up_index(i_spatial)
            bb = down_index(b_spatial)
            jb = down_index(j_spatial)
            #t1 operator
            qulacs_generator = gen_p_t2(aa, ia, bb, jb)
            #Add p-t2 into the circuit
            theta = 0.0
            theta_offsets, ioff = util.add_theta_value_offset(theta_offsets,
                                                   qulacs_generator,
                                                   ioff)
            circuit = util.add_parametric_circuit_using_generator(circuit,
                                                   qulacs_generator,
                                                   theta,i_t2,1.0)
    end
    circuit, theta_offsets
end