export uccgsd, convert_openfermion_op, add_parametric_circuit_using_generator!, add_parametric_multi_Pauli_rotation_gate!

"""
Generate single excitations
"""
function gen_t1(a, i)
    #a^\dagger_a a_i (excitation)
    generator = FermionOperator([(a, 1), (i, 0)], 1.0)
    #-a^\dagger_i a_a (de-exciation)
    generator += FermionOperator([(i, 1), (a, 0)], -1.0)
    #JW-transformation of a^\dagger_a a_i - -a^\dagger_i a_a
    jordan_wigner(generator)
end

"""
Generate pair dobule excitations
"""
function gen_p_t2(aa, ia, ab, ib)
    generator = FermionOperator([
        (aa, 1),
        (ab, 1),
        (ib, 0),
        (ia, 0)],
        1.0)
    generator += FermionOperator([
        (ia, 1),
        (ib, 1),
        (ab, 0),
        (aa, 0)],
        -1.0)
    jordan_wigner(generator)
end


"""
Returns UCCGSD circuit.
"""
function uccgsd(n_qubit, nocc=-1, orbital_rot=false, conserv_Sz_doubles=true, conserv_Sz_singles=true)
    theta_offsets = []
    circuit = QulacsParametricQuantumCircuit(n_qubit)
    ioff = 0

    norb = n_qubit ÷2
    cr_range = orbital_rot ? (1:norb) : (1+nocc:norb)
    anh_range = orbital_rot ? (1:norb) : (1:nocc)

    so_idx(iorb, ispin) = spin_index_functions[ispin](iorb)
    sz = [1, -1]
    
    # Singles
    spin_index_functions = [up_index, down_index]
    for (i_t1, (a_spatial, i_spatial)) in enumerate(Iterators.product(cr_range, anh_range))
        for ispin1 in 1:2, ispin2 in 1:2
            if conserv_Sz_singles && sz[ispin1] + sz[ispin2] != 0
                continue
            end
            #Spatial Orbital Indices
            a_spin_orbital = so_idx(a_spatial, ispin1)
            i_spin_orbital = so_idx(i_spatial, ispin2)
            #t1 operator
            generator = gen_t1(a_spin_orbital, i_spin_orbital)
            #Add t1 into the circuit
            add_parametric_circuit_using_generator!(circuit, generator, 0.0)
        end
    end


    #Doubles
    for (spin_a, spin_i, spin_b, spin_j) in Iterators.product(1:2, 1:2, 1:2, 1:2)
        for (a, i, b, j) in Iterators.product(1:norb, 1:norb, 1:norb, 1:norb)
            if conserv_Sz_doubles && sz[spin_a] + sz[spin_i] + sz[spin_b] + sz[spin_j] != 0
                continue
            end
            #Spatial Orbital Indices
            aa = so_idx(a, spin_a)
            ia = so_idx(i, spin_i)
            bb = so_idx(b, spin_b)
            jb = so_idx(j, spin_j)

            #t2 operator
            generator = gen_p_t2(aa, ia, bb, jb)
            #Add p-t2 into the circuit
            add_parametric_circuit_using_generator!(circuit, generator, 0.0)
         end
      end
    circuit
end
