defmodule ApiConsumer.HTTP.Executor do
  alias ApiConsumer.Requester.{RequestError, RequestAttempt}
  alias ApiConsumer.HTTP
  import ApiConsumer.HTTP.LoggerBackend, only: [log_service_response: 4, log_error: 5]

  @doc """
  Executa o fluxo de uma requisição feita para API de Serviços
  """
  @spec exec(HTTP.Builder.t(), atom, any, keyword) :: {:ok, term} | {:error, term}
  def exec(struct, attempt \\ 1, opts \\ [])

  def exec(%HTTP.Builder{} = struct, attempt, opts) do
    exec(nil, struct, attempt, opts)
  end

  @doc """
  Executa o fluxo de uma requisição feita para API de Serviços da TIM
  recebendo uma possível tentativa de execução anterior.
  """
  @spec exec(attempt_or_error :: any, HTTP.Builder.t(), attempt :: number | Atom.t(), Keyword.t()) ::
          {:ok, term} | {:error, term}
  def exec(_attempt_or_error, _struct, _attempt, _opts)

  def exec(%RequestError{} = request_error, struct, :stop, _opts) do
    api_result =
      request_error
      |> Map.get(:request_attempt, %{})
      |> Map.get(:result)

    log(request_error, struct)

    try do
      result = exec_function(struct, api_result, :after_error)
      {:error, result}
    catch
      _type, error ->
        {:error, error, api_result}
    end
  end

  def exec(%RequestAttempt{} = attempt, struct, :stop, _opts) do
    api_result = Map.get(attempt, :result, %{})

    try do
      api_result = exec_function(struct, api_result, :after_success)
      {:ok, api_result}
    catch
      _type, error ->
        {:error, error, api_result}
    end
  end

  def exec(previus_request, %HTTP.Builder{} = struct, attempt, opts) do
    log(previus_request, struct)

    try do
      requester = struct.opts[:requester]

      struct
      |> RequestAttempt.find_or_create_request_attempt(previus_request)
      |> request(struct, requester, opts)
      |> validate(struct)
      |> parse(struct)
      |> persist(struct)
    catch
      _type, {attempt_or_error, step, error, verbose} ->
        RequestError.with_exception(attempt_or_error, step, error, verbose)

      _type, error ->
        RequestError.with_exception(previus_request, "unexpected_step", error)
    end
    |> finalize(struct, attempt, opts)
  end

  @doc """
  Executa a requisição HTTP baseando-se em um dos `requester/1` implementados:
  - curl
  - httpoison
  """
  def request(request_attempt, %HTTP.Builder{} = struct, requester, opts) do
    opts = Keyword.merge(struct.http_opts, opts)
    url = make_url(struct.url, struct.query_string)

    result =
      requester.request!(
        struct.verb,
        url,
        struct.body,
        struct.headers,
        opts
      )

    log_service_response(
      struct.opts[:log_level],
      struct.opts[:log?],
      struct.name,
      verbose(result)
    )

    RequestAttempt.request_attempt_with_result(request_attempt, result)
  rescue
    exception -> throw({request_attempt, "request", exception, ""})
  end

  @doc """
  Valida a resposta obtida pela api de acordo com a função armazenada
  em `HTTP.Builder.opts[:validate]`
  """
  def validate(_api_result, _struct)
  def validate(%RequestError{} = api_result, _struct), do: api_result

  def validate(%RequestAttempt{} = attempt, struct) do
    result = Map.get(attempt, :result, %{})

    try do
      if exec_function(struct, result, :validate) do
        attempt
      else
        throw({attempt, "validate", nil, Map.get(result, :verbose)})
      end
    rescue
      exception -> throw({attempt, "validate", exception, verbose(result)})
    end
  end

  @doc """
  Realiza a conversão da resposta obtida de acordo com a função armazenada
  em `HTTP.Builder.opts[:parse]`
  """
  def parse(_api_result, _struct)
  def parse(%RequestError{} = api_result, _struct), do: api_result

  def parse(%RequestAttempt{} = attempt, struct) do
    result = Map.get(attempt, :result, %{})

    try do
      Map.update!(attempt, :result, &exec_function(struct, &1, :parse))
    rescue
      exception -> throw({attempt, "parse", exception, verbose(result)})
    end
  end

  @doc """
  TODO: Persiste o resultado de uma requisição na base de dados.
  """
  def persist(_api_result, _struct)

  def persist(%RequestError{} = attempt_error, _struct) do
    result =
      attempt_error
      |> Map.get(:request_attempt, %{})
      |> Map.get(:result, %{})

    try do
      attempt_error
    rescue
      exception -> throw({attempt_error, "persist/error", exception, verbose(result)})
    end
  end

  def persist(%RequestAttempt{} = attempt, _struct) do
    result = Map.get(attempt, :result, %{})

    try do
      # Repo.insert_or_update(result)
      attempt
    rescue
      exception -> throw({attempt, "persist/attempt", exception, verbose(result)})
    end
  end

  @doc """
  Finaliza o fluxo de execução de execução de um serviço onde é feito
  retentativa em caso de erro (baseado na quantidade de tentativas permitidas)
  ou retorna o resultado da api.
  """
  def finalize(_attempt_or_error, _struct, _attempt, _opts)

  def finalize(%RequestError{} = attempt_error, struct, attempt, opts) do
    try do
      new_attempt = RequestAttempt.check_attempt(struct, attempt)
      exec(attempt_error, struct, new_attempt, opts)
    rescue
      exception -> throw(exception)
    end
  catch
    _type, _error ->
      exec(attempt_error, struct, :stop, opts)
  end

  def finalize(%RequestAttempt{} = attempt, struct, _attempt, opts) do
    exec(attempt, struct, :stop, opts)
  end

  #####################
  # PRIVATE FUNCTIONS #
  #####################

  defp exec_function(struct, api_result, opts_key) do
    struct.opts[opts_key].(api_result)
  end

  defp log(%RequestError{} = attempt_error, struct) do
    %RequestError{
      exception: %{
        step: step,
        error: exception,
        request_verbose: request_verbose
      }
    } = attempt_error

    log_error(
      struct.name,
      struct.opts[:log?],
      request_verbose,
      step,
      exception
    )
  end

  defp log(_any, _struct), do: :ok

  @spec make_url(String.t(), String.t()) :: String.t()
  defp make_url(url, "/" <> query_string), do: make_url(url, query_string)
  defp make_url(url, query_string), do: url <> query_string

  defp verbose(%{body: _} = request_result) do
    request_result
    |> Map.update!(:body, &verbose(&1))
    |> _inspect
  end

  defp verbose(request_result), do: _inspect(request_result)

  defp _inspect(value) do
    value
    |> inspect(pretty: true, limit: :infinity, printable_limit: :infinity)
    |> (fn value ->
          Regex.replace(~r/\r\n\t/m, value, "")
        end).()
  end
end
