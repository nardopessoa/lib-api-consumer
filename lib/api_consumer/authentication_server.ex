defmodule ApiConsumer.AuthenticationServer do
  use GenServer

  @doc """
  Realiza a requisição ao GenServer genérico, que mantem em seu estado
  os resultados de logins já realizados. A macro `__using__` já entrega
  esta função implementada, fazendo um delegate para este módulo.
  See `__MODULE__.logon/1` implementation
  """
  @callback logon(login_input :: any) :: any

  @doc """
  Gera uma chave identificadora das entradas de login, utilizada para cachear o
  resultado do login
  """
  @callback cache_key(login_input :: any) :: String.t() | Atom.t()

  @doc """
  Realiza o login na plataforma, retornando dados necessários para as proximas requisições.
  É invocado a cada vez que o resultado de login é requisitado. É de responsabilidade do
  modulo que mantem a funcionalidade de login implementar as regras de peridiocidade
  de atualização dos resultados de login.
  """
  @callback request_logon(login_input :: any, login_result :: any) ::
              {:ok, login_result :: term}
              | {:error, reason :: term}

  @doc """
  Permite se utilizar a macro `use` nos modulos dependentes deste.
  Já entregado a funcao logon implementada.
  """
  defmacro __using__(_) do
    quote do
      @behaviour ApiConsumer.AuthenticationServer

      defdelegate logon(login_input), to: ApiConsumer.AuthenticationServer
      defdelegate cache_key(login_input), to: ApiConsumer.AuthenticationServer

      defoverridable ApiConsumer.AuthenticationServer
    end
  end

  @doc """
  Funcao utilizada para iniciar um processo do GenServer. Normalmente iniciado junto da
  aplciacao ao qual possui um modulo implementador deste `Behaviour`.
  """
  def start_link(worker) do
    GenServer.start_link(__MODULE__, worker, name: __MODULE__)
  end

  @doc """
  Callback do modulo GenServer. Monta o estado inicial do GenServer em questao.
  """
  def init(worker), do: {:ok, {worker, %{}}}

  @doc """
  Funcao responsavel por sincronizar as chamadas de login, impedindo que aconteca mais de um
  login para as mesmas credenciais.
  """
  def logon(login_input), do: GenServer.call(__MODULE__, {:token, login_input}, 10000)

  @doc """
  Função que gera a chave ao qual o resultado do login será armazenado no estado do genserver
  """
  def cache_key(login_input), do: login_input

  @doc """
  Callback do modulo GenServer, executado na chamada de uma funcao call.
  Ver `__MODULE__.logon`.
  """
  def handle_call({:token, login_input}, _from, {worker, state}) do
    cache_key = worker.cache_key(login_input)
    login_cached = Map.get(state, cache_key)
    {:ok, login_result} = worker.request_logon(login_input, login_cached)

    new_state = Map.put(state, cache_key, login_result)

    {:reply, login_result, {worker, new_state}}
  end
end
