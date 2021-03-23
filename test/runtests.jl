using QCMaterial
using QCMaterial.HartreeFock
using Test
using PyCall
import PyCall: pyimport
import QCMaterial: uccgsd, convert_openfermion_op, up_index, down_index


@testset "util.topylist" begin
    org_array = [1, 2, 3.0]
    pylist = topylist(org_array)
    @test all(org_array .== pylist)
end

@testset "util.doublefunc" begin
    org_array = [1, 2, 3]
    @test all(doublefunc(org_array) .== 2 .* org_array)
end


@testset "uccsd.uccgsd" begin
    # construct hamiltonian
    plt = pyimport("matplotlib.pyplot")
    of = pyimport("openfermion")
    ofpyscf = pyimport("openfermionpyscf")
    qulacs = pyimport("qulacs")
    scipy_opt = pyimport("scipy.optimize")
    get_fermion_operator = of.transforms.get_fermion_operator
    jordan_wigner = of.transforms.jordan_wigner
    jw_get_ground_state_at_particle_number = of.linalg.sparse_tools.jw_get_ground_state_at_particle_number
    get_number_preserving_sparse_operator = of.linalg.get_number_preserving_sparse_operator
    FermionOperator = of.ops.operators.FermionOperator

    nsite = 2 
    n_qubit = 2*nsite 
    U = 1.0
    t = -0.01
    μ = 0

    ham = FermionOperator()
    for i in 1:nsite
        up = up_index(i)
        down = down_index(i)
        ham += FermionOperator("$(up)^ $(down)^ $(up) $(down)", -U) 
    end

    for i in 1:nsite-1
        ham += FermionOperator("$(up_index(i+1))^ $(up_index(i))", t) 
        ham += FermionOperator("$(up_index(i))^ $(up_index(i+1))", t) 
        ham += FermionOperator("$(down_index(i+1))^ $(down_index(i))", t) 
        ham += FermionOperator("$(down_index(i))^ $(down_index(i+1))", t) 
    end


    for i in 1:nsite
        up = up_index(i)
        down = down_index(i)
        ham += FermionOperator("$(up)^  $(up) ", -μ) 
        ham += FermionOperator("$(down)^ $(down)", -μ)
    end

    n_electron = 2　
    @assert mod(n_electron, 2) == 0
    sparse_mat = get_number_preserving_sparse_operator(ham, n_qubit, n_electron);　

    using LinearAlgebra
    enes_ed = eigvals(sparse_mat.toarray());　

    jw_hamiltonian = jordan_wigner(ham);
    qulacs_hamiltonian = qulacs.observable.create_observable_from_openfermion_text(jw_hamiltonian.__str__())
    hfstate(n_qubit, n_electron) = parse(Int, repeat("0", n_qubit-n_electron) * repeat("1", n_electron), base=2)

    function update_circuit_param!(circuit::PyObject, theta_list, theta_offsets)
        for (idx, theta) in enumerate(theta_list)
            for ioff in 1:theta_offsets[idx][1]
                pauli_coef = theta_offsets[idx][3][ioff]
                circuit.set_parameter(theta_offsets[idx][2]+ioff-1, 
                                  theta*pauli_coef) 
            end
        end
    end

    circuit, theta_offsets = uccgsd(n_qubit, n_electron÷2, (n_qubit-n_electron)÷2,true)
    function cost(theta_list)
        state = qulacs.QuantumState(n_qubit) 
        state.set_computational_basis(hfstate(n_qubit, n_electron))
        update_circuit_param!(circuit, theta_list, theta_offsets) 
        circuit.update_quantum_state(state) 
        qulacs_hamiltonian.get_expectation_value(state) 
    end

    theta_init = rand(size(theta_offsets)[1])
    cost_history = Float64[] 
    init_theta_list = theta_init
    push!(cost_history, cost(init_theta_list))

    method = "BFGS"
    options = Dict("disp" => true, "maxiter" => 50, "gtol" => 1e-5)
    callback(x) = push!(cost_history, cost(x))
    opt = scipy_opt.minimize(cost, init_theta_list, method=method, callback=callback)

    EigVal_min = minimum(enes_ed)
    #println("EigVal_min=",EigVal_min)
    #println("cost_history_end=",cost_history[end])
    @test abs(EigVal_min-cost_history[end]) < 1e-6 
end

@testset "hartree_fock.extract_tij_Uijlk" begin
    ofermion = pyimport("openfermion")
    FermionOperator = ofermion.ops.operators.FermionOperator
    ham = FermionOperator("1^ 0^ 1 0") + FermionOperator("0^ 0") + FermionOperator("1^ 1", -1.0)
    tij, Uijlk = extract_tij_Uijlk(ham)

    tij_ref = [1.0 0.0; 0.0 -1.0]
    Uijlk_ref = zeros(Float64, 2, 2, 2, 2)
    Uijlk_ref[2, 1, 2, 1] = 2.0
    @test all(tij .== tij_ref)
    @test all(Uijlk .== Uijlk_ref)
end
