defmodule ApiConsumer.HTTP.Builder do
  alias ApiConsumer.HTTP

  @moduledoc """
  Módulo responsável por construir uma estrutura capaz de se conectar a
  uma rota da API da TIM e processar a informação retornada.
  """

  @doc """
  Nome do serviço ao qual será registrado a tentativa de sucesso ou erro.
  """
  @callback service_name() :: String.t()

  @doc """
  Framework utilizado para processar e executar a requisição ao serviço.
  Valores possíveis: :curl, :httpoison
  """
  @callback requester() :: Atom.t()

  @doc """
  Validação feita em cima da resposta do serviço, dizendo se
  o retorno foi satisfatório (true) ou não (false).
  """
  @callback validate(request_result :: Map.t(), extra_info :: any) :: boolean

  @doc """
  Função que executa o serviço propriamente dito. Os parametros customer_id
  e msisdn são obrigatórios devido a necessidade de verificação permissão
  obrigatória em todos os serviços disponiveis
  """
  @callback run(login_input :: Tuple.t(), opts :: Keyword.t()) :: Map.t() | String.t()

  @typedoc """
  Declaracao da estrutura de dados, onde:
    - name: nome que identifica o serviço
    - module: módulo vinculado as configurações do serviço. Utilizado para
      log e para obter informações como: quantidade de tentativas em caso
      de falha, quantidade de tempo de espera entre tentativas, etc.
    - url: url a ser executada
    - verb: verbo http a ser executado (GET, POST, PUT, DELETE, etc.)
    - headers: lista de cabeçalhos a serem enviados
    - body: corpo da requisição a ser enviada (json, chave-valor, etc.)
    - query_string: query string da url (Ex.: http://host.com/?query_string=query_string)
    - http_opts: lista de opções (keyword) a ser passada ao requester
    - opts: Valores possíveis:
      - retry: quantidade de retentativas, em caso de falha
      - sleep_for: tempo de espera entre as tentativas
      - log_level: nível do log a ser realizado
      - log?: flag para indicar se deve ou não realizar log
      - validate: valida uma resposta da requisição
      - parse: função executada para converter uma resposta dada como válida
      - after_success: função executada em caso de sucesso na requisição
      - after_error: função executada em casa de falha de todas as retentativas.
  """
  @type t :: %__MODULE__{}
  defstruct name: nil,
            module: nil,
            url: nil,
            verb: :get,
            headers: [],
            body: "",
            query_string: "",
            http_opts: [],
            opts: []

  for field <- [:module, :verb, :headers, :body, :query_string, :http_opts, :opts] do
    @doc """
    Função responsável por atribuir valor ao campo #{to_string(field)}, baseado
    no design pattern Builder, onde o parametro recebido é atualizado e retornado.
    """
    @spec unquote(field)(__MODULE__.t(), any) :: __MODULE__.t()
    def unquote(field)(struct, value) do
      update_struct_field(struct, unquote(field), value)
    end
  end

  @doc """
  Inicia uma nova estrutura `t` atribuindo apenas o nome na estrutura e atribui
  as configurações disponíveis para o módulo informado na estrutura.
  """
  @spec new(Module.t()) :: __MODULE__.t()
  def new(module) do
    # configurações definidos no behaviour `__MODULE__`
    service_name = module.service_name()
    requester_module = module.requester()
    validate_func = &module.validate/1
    # configuracoes dinâmicas de log
    log? = HTTP.ConfigHelper.log?(module)
    log_level = HTTP.ConfigHelper.log_level(module)
    attempts_amount = HTTP.ConfigHelper.attempts_amount(module)
    sleep_seconds_between_attempts = HTTP.ConfigHelper.sleep_seconds_between_attempts(module)

    init_opts = [
      retry: attempts_amount,
      sleep_for: sleep_seconds_between_attempts,
      log_level: log_level,
      log?: log?,
      validate: validate_func,
      requester: requester_module,
      parse: & &1,
      after_success: & &1,
      after_error: & &1
    ]

    %HTTP.Builder{name: service_name}
    |> module(module)
    |> opts(init_opts)
  end

  @doc """
  Função responsável por definir a url a ser requisitada. Obtem do
  `requester` a base da URL concatenando o valor informado aqui.
  """
  @spec url(__MODULE__.t(), String.t(), String.t()) :: __MODULE__.t()
  def url(struct, url, query_string \\ "") do
    struct
    |> update_struct_field(:url, url)
    |> query_string(query_string)
  end

  @doc """
  Função responsável por armazenar na struct o modulo ao qual irá executar
  validação do resultado retornado na requisição ao serviço da TIM.
  """
  @spec request_with(__MODULE__.t(), Module.t()) :: __MODULE__.t()
  def request_with(struct, requester_module) do
    opts(struct, requester: requester_module)
  end

  @doc """
  Função responsável por armazenar na struct a função executada para
  validação do resultado retornado na requisição ao serviço da TIM.
  """
  @spec validate_with(__MODULE__.t(), Function.t()) :: __MODULE__.t()
  def validate_with(struct, validate_func) do
    opts(struct, validate: validate_func)
  end

  @doc """
  Permite configurar algumas opções utilizadas em caso de erro em qualquer
  fluxo de exceção.
  Opcoes possiveis:
  - retry: integer
  - sleep_for: time. use :timer.seconds(integer)
  - log_level: log_level
  - log?: boolean
  - after_error: function
  """
  @spec when_error(__MODULE__.t(), Keyword.t()) :: __MODULE__.t()
  def when_error(struct, opts) do
    new_opts = Keyword.take(opts, [:retry, :sleep_for, :log_level, :log?, :after_error])
    opts(struct, new_opts)
  end

  @doc """
  Permite configurar algumas opções utilizadas após todas as etapas
  serem executadas com sucesso.
  Opcoes possíveis:
  - parse: function
  - after_success: function
  """
  @spec when_sucess(__MODULE__.t(), Keyword.t()) :: __MODULE__.t()
  def when_sucess(struct, opts) do
    new_opts = Keyword.take(opts, [:parse, :after_success])
    opts(struct, new_opts)
  end

  @doc """
  Atualiza campos do tipo lista da estrutura `__MODULE__.t`
  concatenando o valor existente com o novo.
  """
  @spec update_struct_field(__MODULE__.t(), Atom.t(), Keyword.t()) :: __MODULE__.t()
  def update_struct_field(struct, field, value) when is_list(value) do
    Map.update!(struct, field, &Keyword.merge(&1, value))
  end

  @doc """
  Atualiza campos do tipo lista da estrutura `__MODULE__.t`
  substituindoo valor existente pelo novo.
  """
  @spec update_struct_field(t, Atom.t(), any) :: __MODULE__.t()
  def update_struct_field(struct, field, value) do
    Map.put(struct, field, value)
  end
end
