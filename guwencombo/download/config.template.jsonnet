########################################################################################
#                                 BASIC configuration                                  #
########################################################################################
# Training data path, str
# Must be in CONNLU format (or it's extended version with semantic relation field).
# Can accepted multiple paths when concatenated with ',', "path1,path2"
local training_data_path = std.extVar("training_data_path");
# Validation data path, str
# Can accepted multiple paths when concatenated with ',', "path1,path2"
local validation_data_path = if std.length(std.extVar("validation_data_path")) > 0 then std.extVar("validation_data_path");
# Path to pretrained tokens, str or null
local pretrained_tokens = if std.length(std.extVar("pretrained_tokens")) > 0 then std.extVar("pretrained_tokens");
# Name of pretrained transformer model, str or null
local pretrained_transformer_name = if std.length(std.extVar("pretrained_transformer_name")) > 0 then std.extVar("pretrained_transformer_name");
# Learning rate value, float
local learning_rate = 0.002;
# Number of epochs, int
local num_epochs = std.parseInt(std.extVar("num_epochs"));
# Cuda device id, -1 for cpu, int
local cuda_device = std.parseInt(std.extVar("cuda_device"));
# Minimum number of words in batch, int
local word_batch_size = std.parseInt(std.extVar("word_batch_size"));
# Features used as input, list of str
# Choice "upostag", "xpostag", "lemma"
# Required "token", "char"
local features = std.split(std.extVar("features"), " ");
# Targets of the model, list of str
# Choice "feats", "lemma", "upostag", "xpostag", "semrel". "sent"
# Required "deprel", "head"
local targets = std.split(std.extVar("targets"), " ");
# Word embedding dimension, int
# If pretrained_tokens is not null must much provided dimensionality
local embedding_dim = std.parseInt(std.extVar("embedding_dim"));
# Dropout rate on predictors, float
# All of the models on top of the encoder uses this dropout
local predictors_dropout = 0.25;
# Xpostag embedding dimension, int
# (discarded if xpostag not in features)
local xpostag_dim = 32;
# Upostag embedding dimension, int
# (discarded if upostag not in features)
local upostag_dim = 32;
# Feats embedding dimension, int
# (discarded if feats not in featres)
local feats_dim = 32;
# Lemma embedding dimension, int
# (discarded if lemma not in features)
local lemma_char_dim = 64;
# Character embedding dim, int
local char_dim = 64;
# Word embedding projection dim, int
local projected_embedding_dim = 100;
# Loss weights, dict[str, int]
local loss_weights = {
    xpostag: 0.05,
    upostag: 0.05,
    lemma: 0.05,
    feats: 0.2,
    deprel: 0.8,
    head: 0.2,
    semrel: 0.05,
};
# Encoder hidden size, int
local hidden_size = 512;
# Number of layers in the encoder, int
local num_layers = 2;
# Cycle loss iterations, int
local cycle_loss_n = 0;
# Maximum length of the word, int
# Shorter words are padded, longer - truncated
local word_length = 30;
# Whether to use tensorboard, bool
local use_tensorboard = if std.extVar("use_tensorboard") == "True" then true else false;
# Path for tensorboard metrics, str
local metrics_dir = "./runs";

# Helper functions
local in_features(name) = !(std.length(std.find(name, features)) == 0);
local in_targets(name) = !(std.length(std.find(name, targets)) == 0);
local use_transformer = pretrained_transformer_name != null;

# Verify some configuration requirements
assert in_features("token"): "Key 'token' must be in features!";
assert in_features("char"): "Key 'char' must be in features!";

assert in_targets("deprel"): "Key 'deprel' must be in targets!";
assert in_targets("head"): "Key 'head' must be in targets!";

assert pretrained_tokens == null || pretrained_transformer_name == null: "Can't use pretrained tokens and pretrained transformer at the same time!";

########################################################################################
#                              ADVANCED configuration                                  #
########################################################################################

# Detailed dataset, training, vocabulary and model configuration.
{
    # Configuration type (default or finetuning), str
    type: std.extVar('type'),
    # Datasets used for vocab creation, list of str
    # Choice "train", "valid"
    datasets_for_vocab_creation: ['train'],
    # Path to training data, str
    train_data_path: training_data_path,
    # Path to validation data, str
    validation_data_path: validation_data_path,
    # Dataset reader configuration (conllu format)
    dataset_reader: {
        type: "conllu",
        features: features,
        targets: targets,
        # Whether data contains semantic relation field, bool
        use_sem: if in_targets("semrel") then true else false,
        token_indexers: {
            token: if use_transformer then {
                type: "pretrained_transformer_mismatched_fixed",
                model_name: pretrained_transformer_name,
                tokenizer_kwargs: if std.startsWith(pretrained_transformer_name, "allegro/herbert")
                                  then {use_fast: false} else {},
            } else {
                # SingleIdTokenIndexer, token as single int
                type: "single_id",
            },
            upostag: {
                type: "single_id",
                namespace: "upostag",
                feature_name: "pos_",
            },
            xpostag: {
                type: "single_id",
                namespace: "xpostag",
                feature_name: "tag_",
            },
            lemma: {
                type: "characters_const_padding",
                character_tokenizer: {
                    start_tokens: ["__START__"],
                    end_tokens: ["__END__"],
                },
                # +2 for start and end token
                min_padding_length: word_length + 2,
            },
            char: {
                type: "characters_const_padding",
                character_tokenizer: {
                    start_tokens: ["__START__"],
                    end_tokens: ["__END__"],
                },
                # +2 for start and end token
                min_padding_length: word_length + 2,
            },
            feats: {
                type: "feats_indexer",
            },
        },
        lemma_indexers: {
            char: {
                type: "characters_const_padding",
                namespace: "lemma_characters",
                character_tokenizer: {
                    start_tokens: ["__START__"],
                    end_tokens: ["__END__"],
                },
                # +2 for start and end token
                min_padding_length: word_length + 2,
            },
        },
    },
    # Data loader configuration
    data_loader: {
        batch_sampler: {
            type: "token_count",
            word_batch_size: word_batch_size,
        },
    },
    # Vocabulary configuration
    vocabulary: std.prune({
        type: "from_instances_extended",
        only_include_pretrained_words: true,
        pretrained_files: {
            tokens: pretrained_tokens,
        },
        oov_token: "_",
        padding_token: "__PAD__",
        non_padded_namespaces: ["head_labels"],
    }),
    model: std.prune({
        type: "semantic_multitask",
        text_field_embedder: {
            type: "basic",
            token_embedders: {
                xpostag: if in_features("xpostag") then {
                    type: "embedding",
                    padding_index: 0,
                    embedding_dim: xpostag_dim,
                    vocab_namespace: "xpostag",
                },
                upostag: if in_features("upostag") then {
                    type: "embedding",
                    padding_index: 0,
                    embedding_dim: upostag_dim,
                    vocab_namespace: "upostag",
                },
                token: if use_transformer then {
                    type: "transformers_word_embeddings",
                    model_name: pretrained_transformer_name,
                    projection_dim: projected_embedding_dim,
                    tokenizer_kwargs: if std.startsWith(pretrained_transformer_name, "allegro/herbert")
                                      then {use_fast: false} else {},
                } else {
                    type: "embeddings_projected",
                    embedding_dim: embedding_dim,
                    projection_layer: {
                        in_features: embedding_dim,
                        out_features: projected_embedding_dim,
                        dropout_rate: 0.25,
                        activation: "tanh"
                    },
                    vocab_namespace: "tokens",
                    pretrained_file: pretrained_tokens,
                    trainable: if pretrained_tokens == null then true else false,
                },
                char: {
                    type: "char_embeddings_from_config",
                    embedding_dim: char_dim,
                    dilated_cnn_encoder: {
                        input_dim: char_dim,
                        filters: [512, 256, char_dim],
                        kernel_size: [3, 3, 3],
                        stride: [1, 1, 1],
                        padding: [1, 2, 4],
                        dilation: [1, 2, 4],
                        activations: ["relu", "relu", "linear"],
                    },
                },
                lemma: if in_features("lemma") then {
                    type: "char_embeddings_from_config",
                    embedding_dim: lemma_char_dim,
                    dilated_cnn_encoder: {
                        input_dim: lemma_char_dim,
                        filters: [512, 256, lemma_char_dim],
                        kernel_size: [3, 3, 3],
                        stride: [1, 1, 1],
                        padding: [1, 2, 4],
                        dilation: [1, 2, 4],
                        activations: ["relu", "relu", "linear"],
                    },
                },
                feats: if in_features("feats") then {
                    type: "feats_embedding",
                    padding_index: 0,
                    embedding_dim: feats_dim,
                    vocab_namespace: "feats",
                },
            },
        },
        loss_weights: loss_weights,
        seq_encoder: {
            type: "combo_encoder",
            layer_dropout_probability: 0.33,
            stacked_bilstm: {
                input_size:
                (char_dim + projected_embedding_dim +
                (if in_features('xpostag') then xpostag_dim else 0) +
                (if in_features('lemma') then lemma_char_dim else 0) +
                (if in_features('upostag') then upostag_dim else 0) +
                (if in_features('feats') then feats_dim else 0)),
                hidden_size: hidden_size,
                num_layers: num_layers,
                recurrent_dropout_probability: 0.33,
                layer_dropout_probability: 0.33
            },
        },
        dependency_relation: {
            type: "combo_dependency_parsing_from_vocab",
            vocab_namespace: 'deprel_labels',
            head_predictor: {
                local projection_dim = 512,
                cycle_loss_n: cycle_loss_n,
                head_projection_layer: {
                    in_features: hidden_size * 2,
                    out_features: projection_dim,
                    activation: "tanh",
                },
                dependency_projection_layer: {
                    in_features: hidden_size * 2,
                    out_features: projection_dim,
                    activation: "tanh",
                },
            },
            local projection_dim = 128,
            head_projection_layer: {
                in_features: hidden_size * 2,
                out_features: projection_dim,
                dropout_rate: predictors_dropout,
                activation: "tanh"
            },
            dependency_projection_layer: {
                in_features: hidden_size * 2,
                out_features: projection_dim,
                dropout_rate: predictors_dropout,
                activation: "tanh"
            },
        },
        morphological_feat: if in_targets("feats") then {
            type: "combo_morpho_from_vocab",
            vocab_namespace: "feats_labels",
            input_dim: hidden_size * 2,
            hidden_dims: [128],
            activations: ["tanh", "linear"],
            dropout: [predictors_dropout, 0.0],
            num_layers: 2,
        },
        lemmatizer: if in_targets("lemma") then {
            type: "combo_lemma_predictor_from_vocab",
            char_vocab_namespace: "token_characters",
            lemma_vocab_namespace: "lemma_characters",
            embedding_dim: 256,
            input_projection_layer: {
                in_features: hidden_size * 2,
                out_features: 32,
                dropout_rate: predictors_dropout,
                activation: "tanh"
            },
            filters: [256, 256, 256],
            kernel_size: [3, 3, 3, 1],
            stride: [1, 1, 1, 1],
            padding: [1, 2, 4, 0],
            dilation: [1, 2, 4, 1],
            activations: ["relu", "relu", "relu", "linear"],
        },
        upos_tagger: if in_targets("upostag") then {
            input_dim: hidden_size * 2,
            hidden_dims: [64],
            activations: ["tanh", "linear"],
            dropout: [predictors_dropout, 0.0],
            num_layers: 2,
            vocab_namespace: "upostag_labels"
        },
        xpos_tagger: if in_targets("xpostag") then {
            input_dim: hidden_size * 2,
            hidden_dims: [128],
            activations: ["tanh", "linear"],
            dropout: [predictors_dropout, 0.0],
            num_layers: 2,
            vocab_namespace: "xpostag_labels"
        },
        semantic_relation: if in_targets("semrel") then {
            input_dim: hidden_size * 2,
            hidden_dims: [64],
            activations: ["tanh", "linear"],
            dropout: [predictors_dropout, 0.0],
            num_layers: 2,
            vocab_namespace: "semrel_labels"
        },
        regularizer: {
            regexes: [
                [".*conv1d.*", {type: "l2", alpha: 1e-6}],
                [".*forward.*", {type: "l2", alpha: 1e-6}],
                [".*backward.*", {type: "l2", alpha: 1e-6}],
                [".*char_embed.*", {type: "l2", alpha: 1e-5}],
            ],
        },
    }),
    trainer: std.prune({
        checkpointer: {
            type: "finishing_only_checkpointer",
        },
        type: "gradient_descent_validate_n",
        cuda_device: cuda_device,
        grad_clipping: 5.0,
        num_epochs: num_epochs,
        optimizer: {
            type: "adam",
            lr: learning_rate,
            betas: [0.9, 0.9],
        },
        patience: 1, # it will  be overwriten by callback
        epoch_callbacks: [
            { type: "transfer_patience" },
        ],
        learning_rate_scheduler: {
            type: "combo_scheduler",
        },
        tensorboard_writer: if use_tensorboard then {
            serialization_dir: metrics_dir,
            should_log_learning_rate: false,
            should_log_parameter_statistics: false,
            summary_interval: 100,
        },
        validation_metric: "+EM",
    }),
}
