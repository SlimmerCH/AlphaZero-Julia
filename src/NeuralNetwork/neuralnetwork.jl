module neuralnetwork

    export NeuralNetwork, set_learning_rate, train, loss, gpu, cpu, get_params, load_params

    import Flux, CUDA, FileIO
    using Flux: relu, tanh
    using LinearAlgebra: dot
    using ProgressMeter

    
    function tuple(args...)
        return args
    end

    ResBlock(channels) = Flux.Chain(
        Flux.SkipConnection(
            Flux.Chain(
                # Conv layer with kernel size 1x1
                Flux.Conv((3, 3), channels => channels, pad=(1,1)),
                Flux.BatchNorm(channels, relu),
                # Conv layer with kernel size 1x1
                Flux.Conv((3, 3), channels => channels, pad=(1,1)),
                Flux.BatchNorm(channels)
            ),
            +
        ),
        relu
    )

    ValueHead(dim1, dim2, in_channels) = Flux.Chain(
        # Conv layer with kernel size 1x1
        Flux.Conv((1, 1), in_channels=>in_channels, pad=(1, 1)),
        Flux.BatchNorm(in_channels, relu), # Batch normalization

        # Flatten the output from 4D tensor to 2D tensor which can be taken by Dense layers
        Flux.flatten,

        # Fully connected layer with hidden size 256
        Flux.Dense((dim1+2)*(dim2+2)*in_channels, in_channels, relu),

        # Output layer - Fully connected. Adjust the output size according to your needs
        Flux.Dense(in_channels, 1, tanh)
    )

    PolicyHead(dim1, dim2, in_channels, policy_outputs) = Flux.Chain(
        Flux.Conv((1, 1), in_channels=>in_channels, pad=(1, 1)), # Convolution2D with 2 filters
        Flux.BatchNorm(in_channels, relu), # Batch normalization
        Flux.flatten,
        Flux.Dense((dim1+2)*(dim2+2)*in_channels, policy_outputs, relu),
        Flux.softmax # softmax activation to get probability distribution
    )

    mutable struct NeuralNetwork
        model::Flux.Chain
        optimizer

        function NeuralNetwork(
            board_dimensions::Tuple{Int, Int},
            in_channels::Int, hidden_layer_size::Int,
            res_blocks::Int,
            policy_outputs::Int
        )

            dim1, dim2 = board_dimensions
            model = Flux.Chain(
                # Input is a 115 planes (5x5) stack, Conv layer with kernel size 3x3 and 256 filters
                Flux.Conv((3, 3), in_channels=>hidden_layer_size, pad=(1, 1)),
                Flux.BatchNorm(hidden_layer_size, relu), # Batch normalization

                [ResBlock(hidden_layer_size) for _ in 1:res_blocks]...,
                
                # Policy and value head
                Flux.Parallel(tuple,
                    PolicyHead(dim1, dim2, hidden_layer_size, policy_outputs),
                    ValueHead(dim1, dim2, hidden_layer_size)
                ) 
                
            ) |> Flux.gpu

            optimizer = Flux.ADAM(0.001) |> Flux.gpu
            new(model, optimizer)
        end
    end

    function (nn::NeuralNetwork)(x)
        # x isa CUDA.CuArray || error("Array must be moved to the gpu before query.\n\tUse gpu() to parse.")
        return nn.model(x)
    end

    function set_learning_rate(nn::NeuralNetwork, lr)
        0 <= lr <= 1 || error("The learning rate ranges from 0 to 1")
        nn.optimizer = Flux.ADAM(lr)
    end

    function train(nn::NeuralNetwork, train_data, epochs = 1)
        loss_function(x, y) = _loss(nn.model, x, y)
        @showprogress for i in 1:epochs
            Flux.train!(loss_function, Flux.params(nn.model) , train_data, nn.optimizer)
        end
    end

    function loss(nn::NeuralNetwork, x, y)
        return _loss(nn.model, x, y)
    end

    function gpu(data)
        if data isa NeuralNetwork
            data.model = data.model |> Flux.gpu
            data.optimizer = data.optimizer |> Flux.gpu
        end
        return data |> Flux.gpu
    end

    function cpu(data)
        return data |> Flux.cpu
    end

    function get_params(nn::NeuralNetwork)
        return Flux.params(nn.model)
    end

    function load_params(nn::NeuralNetwork, params)
        Flux.loadparams!(nn.model, params)
    end

    function _loss(model, x, y)
        p, v = model(x)
        π_, z = y
        θ = Flux.params(model)
        l = Flux.mse(v, z) + Flux.crossentropy(p, π_) + dot(θ, θ)
        return l
    end

end