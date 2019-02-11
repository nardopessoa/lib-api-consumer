defmodule ApiConsumer.Requester.RequestError do
  alias ApiConsumer.Requester

  @moduledoc """
  Entidade responsável por registrar e manter os dados utilizados
  nas requisições finalizadas com erro.

  :request_attempt - referencia utilizada pra obter dados do serviço

  :parent - referencia da primeira requisição de erro da sequencia.
    Caso seja nulo, significa ser a primeira requisição das tentativas.
  :children - referenca das tentativas subsequentes a primeira requisição
    com erro.

  :url - url utilizada para realizar a requisição
  :error_type - tipo de erro encontrado. Ex.: http_timeout, parse_error,
    api_error (erro generico), undefined, etc.
  :request - JSON com os atributos utilizados na requisição:
    headers, body, http_verb, etc.
  :response - JSON com os atributos recebidos como resposta do serviço:
    headers, body, http_code, etc.
  :max_attempts - número máximo de tentativas ao qual o serviço estava
    configurado no momento da requisição. Por ser um parametro dinamico,
    decidiu-se armazenar este valor para manter um histórico.

  :created_at - timestamp em que a requisição foi executada
  :updated_at - timestamp em que o serviço recebeu a resposta do servidor
  """

  defstruct request_attempt: nil,

            # %Requester.RequestAttempt{}
            # %Requester.RequestError{}
            parent: nil,
            # %Requester.RequestError{} # foreign_key: :parent_id
            children: [],
            # :string
            url: nil,
            # :string
            error_type: nil,
            # :map
            request: nil,
            # :map
            response: nil,
            # :integer
            max_attempts: nil,
            # :map
            exception: nil,
            created_at: Timex.now(),
            updated_at: Timex.now()

  def with_exception(attempt_or_error, step, exception, verbose \\ "", parent \\ nil)

  def with_exception(%__MODULE__{} = request_error, step, exception, verbose, _parent) do
    attempt = request_error.request_attempt
    parent_error = request_error.parent || request_error
    with_exception(attempt, step, exception, verbose, parent_error)
  end

  def with_exception(
        %Requester.RequestAttempt{} = request_attempt,
        step,
        exception,
        verbose,
        parent
      ) do
    %__MODULE__{
      request_attempt: request_attempt,
      exception: %{
        step: step,
        error: exception,
        request_verbose: verbose
      },
      parent: parent
    }
  end
end
