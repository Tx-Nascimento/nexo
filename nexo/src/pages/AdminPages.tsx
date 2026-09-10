import { useEffect, useState } from 'react'
import type {
  Cargo,
  DadosUsuario,
  Empresa,
  Operacao,
  Pessoa,
  Processo,
  Recorrencia,
  Responsabilidade,
  Setor,
} from '../types'

import {
  atualizarAcesso,
  atualizarEmpresa,
  listarCargos,
  listarOperacoes,
  listarPerfis,
  listarPessoas,
  listarProcessos,
  listarRecorrencias,
  listarResponsabilidades,
  listarSetores,
  listarUsuariosEmpresa,
  buscarEmpresa,
  salvarCargo,
  salvarOperacao,
  salvarPessoa,
  salvarProcesso,
  salvarRecorrencia,
  salvarResponsabilidade,
  salvarSetor,
  statusCargo,
  statusOperacao,
  statusPessoa,
  statusProcesso,
  statusRecorrencia,
  statusResponsabilidade,
  statusSetor,
} from '../services/nexoService'

function Cabecalho({
  titulo,
  descricao,
  usuario,
}: {
  titulo: string
  descricao: string
  usuario: DadosUsuario
}) {
  return (
    <header className="topbar">
      <div>
        <h1>{titulo}</h1>
        <p>{descricao}</p>
      </div>

      <div className="topbar-user">{usuario.nome}</div>
    </header>
  )
}

function Status({ ativo }: { ativo: boolean }) {
  return (
    <span className={ativo ? 'status-active' : 'status-inactive'}>
      {ativo ? 'Ativo' : 'Inativo'}
    </span>
  )
}

function Voltar({
  voltar,
  children,
}: {
  voltar: () => void
  children?: React.ReactNode
}) {
  return (
    <div className="page-actions">
      <button className="secondary-button" onClick={voltar}>
        ← Voltar
      </button>

      {children}
    </div>
  )
}

export function AdministracaoPage({
  usuario,
  navegar,
}: {
  usuario: DadosUsuario
  navegar: (pagina: any) => void
}) {
  const modulos = [
    ['Empresas', 'Dados cadastrais da organização.', 'empresas'],
    ['Setores', 'Departamentos e áreas da empresa.', 'setores'],
    ['Cargos', 'Estrutura de cargos da organização.', 'cargos'],
    ['Pessoas', 'Colaboradores vinculados à empresa.', 'pessoas'],
    ['Perfis e acessos', 'Perfis e acessos dos usuários.', 'perfis'],
    ['Processos', 'Processos executados pelos setores.', 'processos'],
    [
      'Operações',
      'Rotinas e atividades pertencentes aos processos.',
      'cadastro-operacoes',
    ],
    [
      'Responsabilidades',
      'Responsáveis, executores, backups e demais papéis.',
      'responsabilidades',
    ],
    [
      'Recorrências',
      'Periodicidade, prazos e SLA das operações.',
      'recorrencias',
    ],
  ]

  return (
    <>
      <Cabecalho
        titulo="Administração"
        descricao="Estrutura organizacional e operacional do NEXO"
        usuario={usuario}
      />

      <section className="admin-grid">
        {modulos.map(([titulo, descricao, pagina]) => (
          <button
            key={pagina}
            className="admin-card"
            onClick={() => navegar(pagina)}
          >
            <div className="admin-card-title">{titulo}</div>
            <p>{descricao}</p>
          </button>
        ))}
      </section>
    </>
  )
}

export function EmpresasPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [empresa, setEmpresa] = useState<Empresa | null>(null)
  const [nome, setNome] = useState('')
  const [fantasia, setFantasia] = useState('')
  const [cnpj, setCnpj] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const data: any = await buscarEmpresa(usuario.empresaId)

      setEmpresa(data)
      setNome(data.nome || '')
      setFantasia(data.nome_fantasia || '')
      setCnpj(data.cnpj || '')
    } catch {
      setMensagem('Erro ao carregar a empresa.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    if (!nome.trim()) {
      setMensagem('Informe o nome da empresa.')
      return
    }

    try {
      await atualizarEmpresa(usuario.empresaId, {
        nome: nome.trim(),
        nome_fantasia: fantasia.trim() || null,
        cnpj: cnpj.trim() || null,
      })

      setMensagem('Empresa atualizada com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível atualizar a empresa.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Empresa"
        descricao="Dados cadastrais da organização"
        usuario={usuario}
      />

      <Voltar voltar={voltar} />

      {mensagem && (
        <div className="system-message">
          {mensagem}
        </div>
      )}

      <section className="panel">
        <div className="panel-header">
          <h3>Dados da empresa</h3>
          <p>Empresa vinculada ao ambiente atual.</p>
        </div>

        <form
          className="sector-form"
          onSubmit={salvar}
        >
          <div className="form-group">
            <label>Razão social / Nome</label>

            <input
              value={nome}
              onChange={(e) =>
                setNome(e.target.value)
              }
              required
            />
          </div>

          <div className="form-row">
            <div className="form-group">
              <label>Nome fantasia</label>

              <input
                value={fantasia}
                onChange={(e) =>
                  setFantasia(e.target.value)
                }
              />
            </div>

            <div className="form-group">
              <label>CNPJ</label>

              <input
                value={cnpj}
                onChange={(e) =>
                  setCnpj(e.target.value)
                }
              />
            </div>
          </div>

          <div className="form-actions">
            <button
              className="primary-button"
              type="submit"
            >
              Salvar alterações
            </button>
          </div>
        </form>
      </section>

      {empresa && (
        <div className="system-message">
          Status atual:{' '}
          {empresa.ativo ? 'Ativa' : 'Inativa'}
        </div>
      )}
    </>
  )
}

export function SetoresPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Setor[]>([])
  const [editando, setEditando] = useState<Setor | null>(null)
  const [form, setForm] = useState(false)
  const [nome, setNome] = useState('')
  const [descricao, setDescricao] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      setDados((await listarSetores(usuario.empresaId)) as unknown as Setor[])
    } catch {
      setMensagem('Erro ao carregar setores.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setNome('')
    setDescricao('')
    setForm(true)
  }

  function editar(item: Setor) {
    setEditando(item)
    setNome(item.nome)
    setDescricao(item.descricao || '')
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    try {
      await salvarSetor(usuario.empresaId, editando?.id || null, {
        nome: nome.trim(),
        descricao: descricao.trim() || null,
      })

      setForm(false)
      setMensagem('Setor salvo com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar o setor.')
    }
  }

  async function alterar(item: Setor) {
    if (!confirm(`${item.ativo ? 'Inativar' : 'Reativar'} "${item.nome}"?`))
      return

    try {
      await statusSetor(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar o setor.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Setores"
        descricao="Cadastro e gerenciamento dos setores"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Novo setor
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <div className="panel-header">
            <h3>{editando ? 'Editar setor' : 'Novo setor'}</h3>
          </div>

          <form className="sector-form" onSubmit={salvar}>
            <div className="form-group">
              <label>Nome</label>
              <input
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>
              <textarea
                rows={4}
                value={descricao}
                onChange={(e) => setDescricao(e.target.value)}
              />
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>

              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={['Setor', 'Descrição', 'Status', 'Ações']}
        linhas={dados.map((item) => [
          <strong>{item.nome}</strong>,
          item.descricao || '—',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function CargosPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Cargo[]>([])
  const [editando, setEditando] = useState<Cargo | null>(null)
  const [form, setForm] = useState(false)
  const [nome, setNome] = useState('')
  const [descricao, setDescricao] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      setDados((await listarCargos(usuario.empresaId)) as unknown as Cargo[])
    } catch {
      setMensagem('Erro ao carregar cargos.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setNome('')
    setDescricao('')
    setForm(true)
  }

  function editar(item: Cargo) {
    setEditando(item)
    setNome(item.nome)
    setDescricao(item.descricao || '')
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    try {
      await salvarCargo(usuario.empresaId, editando?.id || null, {
        nome: nome.trim(),
        descricao: descricao.trim() || null,
      })

      setForm(false)
      setMensagem('Cargo salvo com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar o cargo.')
    }
  }

  async function alterar(item: Cargo) {
    if (!confirm(`${item.ativo ? 'Inativar' : 'Reativar'} "${item.nome}"?`))
      return

    try {
      await statusCargo(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar o cargo.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Cargos"
        descricao="Cadastro e gerenciamento dos cargos"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Novo cargo
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <div className="panel-header">
            <h3>{editando ? 'Editar cargo' : 'Novo cargo'}</h3>
          </div>

          <form className="sector-form" onSubmit={salvar}>
            <div className="form-group">
              <label>Nome</label>
              <input
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>
              <textarea
                rows={4}
                value={descricao}
                onChange={(e) => setDescricao(e.target.value)}
              />
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={['Cargo', 'Descrição', 'Status', 'Ações']}
        linhas={dados.map((item) => [
          <strong>{item.nome}</strong>,
          item.descricao || '—',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function PessoasPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Pessoa[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [cargos, setCargos] = useState<Cargo[]>([])
  const [editando, setEditando] = useState<Pessoa | null>(null)
  const [form, setForm] = useState(false)
  const [nome, setNome] = useState('')
  const [email, setEmail] = useState('')
  const [setorId, setSetorId] = useState('')
  const [cargoId, setCargoId] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [p, s, c] = await Promise.all([
        listarPessoas(usuario.empresaId),
        listarSetores(usuario.empresaId),
        listarCargos(usuario.empresaId),
      ])

      setDados(p as unknown as Pessoa[])
      setSetores(s as unknown as Setor[])
      setCargos(c as unknown as Cargo[])
    } catch {
      setMensagem('Erro ao carregar pessoas.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setNome('')
    setEmail('')
    setSetorId('')
    setCargoId('')
    setForm(true)
  }

  function editar(item: Pessoa) {
    setEditando(item)
    setNome(item.nome)
    setEmail(item.email || '')
    setSetorId(item.setor_id || '')
    setCargoId(item.cargo_id || '')
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    try {
      await salvarPessoa(usuario.empresaId, editando?.id || null, {
        nome: nome.trim(),
        email: email.trim().toLowerCase() || null,
        setor_id: setorId || null,
        cargo_id: cargoId || null,
      })

      setForm(false)
      setMensagem('Pessoa salva com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar a pessoa.')
    }
  }

  async function alterar(item: Pessoa) {
    if (!confirm(`${item.ativo ? 'Inativar' : 'Reativar'} "${item.nome}"?`))
      return

    try {
      await statusPessoa(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar a pessoa.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Pessoas"
        descricao="Cadastro dos colaboradores da organização"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Nova pessoa
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <div className="panel-header">
            <h3>{editando ? 'Editar pessoa' : 'Nova pessoa'}</h3>
          </div>

          <form className="sector-form" onSubmit={salvar}>
            <div className="form-row">
              <div className="form-group">
                <label>Nome</label>
                <input
                  value={nome}
                  onChange={(e) => setNome(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label>E-mail</label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Setor</label>
                <select
                  value={setorId}
                  onChange={(e) => setSetorId(e.target.value)}
                >
                  <option value="">Sem setor</option>
                  {setores
                    .filter((x) => x.ativo || x.id === setorId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-group">
                <label>Cargo</label>
                <select
                  value={cargoId}
                  onChange={(e) => setCargoId(e.target.value)}
                >
                  <option value="">Sem cargo</option>
                  {cargos
                    .filter((x) => x.ativo || x.id === cargoId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={[
          'Pessoa',
          'Setor',
          'Cargo',
          'E-mail',
          'Status',
          'Ações',
        ]}
        linhas={dados.map((item) => [
          <strong>{item.nome}</strong>,
          item.setor?.nome || '—',
          item.cargo?.nome || '—',
          item.email || '—',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function ProcessosPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Processo[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [editando, setEditando] = useState<Processo | null>(null)
  const [form, setForm] = useState(false)
  const [nome, setNome] = useState('')
  const [descricao, setDescricao] = useState('')
  const [setorId, setSetorId] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [p, s] = await Promise.all([
        listarProcessos(usuario.empresaId),
        listarSetores(usuario.empresaId),
      ])

      setDados(p as unknown as Processo[])
      setSetores(s as unknown as Setor[])
    } catch {
      setMensagem('Erro ao carregar processos.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setNome('')
    setDescricao('')
    setSetorId('')
    setForm(true)
  }

  function editar(item: Processo) {
    setEditando(item)
    setNome(item.nome)
    setDescricao(item.descricao || '')
    setSetorId(item.setor_id)
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    if (!setorId) {
      setMensagem('Selecione o setor.')
      return
    }

    try {
      await salvarProcesso(usuario.empresaId, editando?.id || null, {
        setor_id: setorId,
        nome: nome.trim(),
        descricao: descricao.trim() || null,
      })

      setForm(false)
      setMensagem('Processo salvo com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar o processo.')
    }
  }

  async function alterar(item: Processo) {
    if (!confirm(`${item.ativo ? 'Inativar' : 'Reativar'} "${item.nome}"?`))
      return

    try {
      await statusProcesso(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar o processo.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Processos"
        descricao="Estrutura dos processos da organização"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Novo processo
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <div className="panel-header">
            <h3>{editando ? 'Editar processo' : 'Novo processo'}</h3>
          </div>

          <form className="sector-form" onSubmit={salvar}>
            <div className="form-group">
              <label>Setor</label>
              <select
                value={setorId}
                onChange={(e) => setSetorId(e.target.value)}
                required
              >
                <option value="">Selecione</option>
                {setores
                  .filter((x) => x.ativo || x.id === setorId)
                  .map((x) => (
                    <option value={x.id} key={x.id}>
                      {x.nome}
                    </option>
                  ))}
              </select>
            </div>

            <div className="form-group">
              <label>Nome do processo</label>
              <input
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>
              <textarea
                rows={4}
                value={descricao}
                onChange={(e) => setDescricao(e.target.value)}
              />
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={['Processo', 'Setor', 'Descrição', 'Status', 'Ações']}
        linhas={dados.map((item) => [
          <strong>{item.nome}</strong>,
          item.setor?.nome || '—',
          item.descricao || '—',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function OperacoesCadastroPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Operacao[]>([])
  const [setores, setSetores] = useState<Setor[]>([])
  const [processos, setProcessos] = useState<Processo[]>([])
  const [editando, setEditando] = useState<Operacao | null>(null)
  const [form, setForm] = useState(false)

  const [setorId, setSetorId] = useState('')
  const [processoId, setProcessoId] = useState('')
  const [nome, setNome] = useState('')
  const [descricao, setDescricao] = useState('')
  const [tipo, setTipo] = useState('ROTINA')
  const [prioridade, setPrioridade] = useState('NORMAL')
  const [tempo, setTempo] = useState('')
  const [conferencia, setConferencia] = useState(false)
  const [aprovacao, setAprovacao] = useState(false)
  const [evidencia, setEvidencia] = useState(false)
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [o, s, p] = await Promise.all([
        listarOperacoes(usuario.empresaId),
        listarSetores(usuario.empresaId),
        listarProcessos(usuario.empresaId),
      ])

      setDados(o as unknown as Operacao[])
      setSetores(s as unknown as Setor[])
      setProcessos(p as unknown as Processo[])
    } catch {
      setMensagem('Erro ao carregar operações.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setSetorId('')
    setProcessoId('')
    setNome('')
    setDescricao('')
    setTipo('ROTINA')
    setPrioridade('NORMAL')
    setTempo('')
    setConferencia(false)
    setAprovacao(false)
    setEvidencia(false)
    setForm(true)
  }

  function editar(item: Operacao) {
    setEditando(item)
    setSetorId(item.setor_id)
    setProcessoId(item.processo_id)
    setNome(item.nome)
    setDescricao(item.descricao || '')
    setTipo(item.tipo)
    setPrioridade(item.prioridade)
    setTempo(item.tempo_estimado_minutos?.toString() || '')
    setConferencia(item.exige_conferencia)
    setAprovacao(item.exige_aprovacao)
    setEvidencia(item.exige_evidencia)
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    if (!setorId || !processoId) {
      setMensagem('Selecione setor e processo.')
      return
    }

    const processoSelecionado = processos.find(
      (x) => x.id === processoId
    )

    if (processoSelecionado?.setor_id !== setorId) {
      setMensagem('O processo selecionado não pertence ao setor.')
      return
    }

    try {
      await salvarOperacao(usuario.empresaId, editando?.id || null, {
        setor_id: setorId,
        processo_id: processoId,
        nome: nome.trim(),
        descricao: descricao.trim() || null,
        tipo,
        prioridade,
        tempo_estimado_minutos: tempo ? Number(tempo) : null,
        exige_conferencia: conferencia,
        exige_aprovacao: aprovacao,
        exige_evidencia: evidencia,
      })

      setForm(false)
      setMensagem('Operação salva com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar a operação.')
    }
  }

  async function alterar(item: Operacao) {
    if (!confirm(`${item.ativo ? 'Inativar' : 'Reativar'} "${item.nome}"?`))
      return

    try {
      await statusOperacao(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar a operação.')
    }
  }

  const processosSetor = processos.filter(
    (x) => x.setor_id === setorId && (x.ativo || x.id === processoId)
  )

  return (
    <>
      <Cabecalho
        titulo="Operações"
        descricao="Cadastro das rotinas e atividades dos processos"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Nova operação
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <div className="panel-header">
            <h3>{editando ? 'Editar operação' : 'Nova operação'}</h3>
          </div>

          <form className="sector-form" onSubmit={salvar}>
            <div className="form-row">
              <div className="form-group">
                <label>Setor</label>
                <select
                  value={setorId}
                  onChange={(e) => {
                    setSetorId(e.target.value)
                    setProcessoId('')
                  }}
                  required
                >
                  <option value="">Selecione</option>
                  {setores
                    .filter((x) => x.ativo || x.id === setorId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-group">
                <label>Processo</label>
                <select
                  value={processoId}
                  onChange={(e) => setProcessoId(e.target.value)}
                  required
                >
                  <option value="">Selecione</option>
                  {processosSetor.map((x) => (
                    <option value={x.id} key={x.id}>
                      {x.nome}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Nome</label>
              <input
                value={nome}
                onChange={(e) => setNome(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label>Descrição</label>
              <textarea
                rows={3}
                value={descricao}
                onChange={(e) => setDescricao(e.target.value)}
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label>Tipo</label>
                <select
                  value={tipo}
                  onChange={(e) => setTipo(e.target.value)}
                >
                  {[
                    'ROTINA',
                    'DEMANDA',
                    'OBRIGACAO',
                    'APROVACAO',
                    'PROTOCOLO',
                    'INCIDENTE',
                    'PROJETO',
                    'AUDITORIA',
                  ].map((x) => (
                    <option key={x}>{x}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Prioridade</label>
                <select
                  value={prioridade}
                  onChange={(e) => setPrioridade(e.target.value)}
                >
                  <option>BAIXA</option>
                  <option>NORMAL</option>
                  <option>ALTA</option>
                  <option>CRITICA</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Tempo estimado em minutos</label>
              <input
                type="number"
                min="0"
                value={tempo}
                onChange={(e) => setTempo(e.target.value)}
              />
            </div>

            <div className="checkbox-grid">
              <label>
                <input
                  type="checkbox"
                  checked={conferencia}
                  onChange={(e) => setConferencia(e.target.checked)}
                />
                Exige conferência
              </label>

              <label>
                <input
                  type="checkbox"
                  checked={aprovacao}
                  onChange={(e) => setAprovacao(e.target.checked)}
                />
                Exige aprovação
              </label>

              <label>
                <input
                  type="checkbox"
                  checked={evidencia}
                  onChange={(e) => setEvidencia(e.target.checked)}
                />
                Exige evidência
              </label>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={[
          'Operação',
          'Setor',
          'Processo',
          'Tipo',
          'Prioridade',
          'Status',
          'Ações',
        ]}
        linhas={dados.map((item) => [
          <strong>{item.nome}</strong>,
          item.setor?.nome || '—',
          item.processo?.nome || '—',
          item.tipo,
          item.prioridade,
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function ResponsabilidadesPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Responsabilidade[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [pessoas, setPessoas] = useState<Pessoa[]>([])
  const [editando, setEditando] = useState<Responsabilidade | null>(
    null
  )
  const [form, setForm] = useState(false)
  const [operacaoId, setOperacaoId] = useState('')
  const [pessoaId, setPessoaId] = useState('')
  const [papel, setPapel] = useState('RESPONSAVEL')
  const [principal, setPrincipal] = useState(false)
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [r, o, p] = await Promise.all([
        listarResponsabilidades(usuario.empresaId),
        listarOperacoes(usuario.empresaId),
        listarPessoas(usuario.empresaId),
      ])

      setDados(r as unknown as Responsabilidade[])
      setOperacoes(o as unknown as Operacao[])
      setPessoas(p as unknown as Pessoa[])
    } catch {
      setMensagem('Erro ao carregar responsabilidades.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setOperacaoId('')
    setPessoaId('')
    setPapel('RESPONSAVEL')
    setPrincipal(false)
    setForm(true)
  }

  function editar(item: Responsabilidade) {
    setEditando(item)
    setOperacaoId(item.operacao_id)
    setPessoaId(item.pessoa_id)
    setPapel(item.papel)
    setPrincipal(item.principal)
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    try {
      await salvarResponsabilidade(editando?.id || null, {
        operacao_id: operacaoId,
        pessoa_id: pessoaId,
        papel,
        principal,
      })

      setForm(false)
      setMensagem('Responsabilidade salva com sucesso.')
      await carregar()
    } catch (e: any) {
      if (e?.code === '23505') {
        setMensagem(
          'Essa pessoa já possui esse papel nesta operação.'
        )
      } else {
        setMensagem('Não foi possível salvar a responsabilidade.')
      }
    }
  }

  async function alterar(item: Responsabilidade) {
    try {
      await statusResponsabilidade(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar a responsabilidade.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Responsabilidades"
        descricao="Papéis das pessoas dentro das operações"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Nova responsabilidade
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <form className="sector-form" onSubmit={salvar}>
            <div className="form-row">
              <div className="form-group">
                <label>Operação</label>
                <select
                  value={operacaoId}
                  onChange={(e) => setOperacaoId(e.target.value)}
                  required
                >
                  <option value="">Selecione</option>
                  {operacoes
                    .filter((x) => x.ativo || x.id === operacaoId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-group">
                <label>Pessoa</label>
                <select
                  value={pessoaId}
                  onChange={(e) => setPessoaId(e.target.value)}
                  required
                >
                  <option value="">Selecione</option>
                  {pessoas
                    .filter((x) => x.ativo || x.id === pessoaId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>
            </div>

            <div className="form-group">
              <label>Papel</label>
              <select
                value={papel}
                onChange={(e) => setPapel(e.target.value)}
              >
                <option>RESPONSAVEL</option>
                <option>EXECUTOR</option>
                <option>APOIO</option>
                <option>BACKUP</option>
                <option>CONFERENTE</option>
                <option>APROVADOR</option>
              </select>
            </div>

            <label className="check-line">
              <input
                type="checkbox"
                checked={principal}
                onChange={(e) => setPrincipal(e.target.checked)}
              />
              Responsável principal
            </label>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={[
          'Operação',
          'Pessoa',
          'Papel',
          'Principal',
          'Status',
          'Ações',
        ]}
        linhas={dados.map((item) => [
          item.operacao?.nome || '—',
          <strong>{item.pessoa?.nome || '—'}</strong>,
          item.papel,
          item.principal ? 'Sim' : 'Não',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function RecorrenciasPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [dados, setDados] = useState<Recorrencia[]>([])
  const [operacoes, setOperacoes] = useState<Operacao[]>([])
  const [editando, setEditando] = useState<Recorrencia | null>(null)
  const [form, setForm] = useState(false)

  const [operacaoId, setOperacaoId] = useState('')
  const [tipo, setTipo] = useState('DIARIA')
  const [diaSemana, setDiaSemana] = useState('')
  const [diaMes, setDiaMes] = useState('')
  const [dataEspecifica, setDataEspecifica] = useState('')
  const [hora, setHora] = useState('')
  const [prazo, setPrazo] = useState('')
  const [sla, setSla] = useState('')
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [r, o] = await Promise.all([
        listarRecorrencias(usuario.empresaId),
        listarOperacoes(usuario.empresaId),
      ])

      setDados(r as unknown as Recorrencia[])
      setOperacoes(o as unknown as Operacao[])
    } catch {
      setMensagem('Erro ao carregar recorrências.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  function novo() {
    setEditando(null)
    setOperacaoId('')
    setTipo('DIARIA')
    setDiaSemana('')
    setDiaMes('')
    setDataEspecifica('')
    setHora('')
    setPrazo('')
    setSla('')
    setForm(true)
  }

  function editar(item: Recorrencia) {
    setEditando(item)
    setOperacaoId(item.operacao_id)
    setTipo(item.tipo_recorrencia)
    setDiaSemana(item.dia_semana?.toString() || '')
    setDiaMes(item.dia_mes?.toString() || '')
    setDataEspecifica(item.data_especifica || '')
    setHora(item.hora_prevista || '')
    setPrazo(item.prazo_minutos?.toString() || '')
    setSla(item.sla_minutos?.toString() || '')
    setForm(true)
  }

  async function salvar(e: React.FormEvent) {
    e.preventDefault()

    try {
      await salvarRecorrencia(editando?.id || null, {
        operacao_id: operacaoId,
        tipo_recorrencia: tipo,
        dia_semana:
          tipo === 'SEMANAL' && diaSemana
            ? Number(diaSemana)
            : null,
        dia_mes:
          tipo === 'MENSAL' && diaMes ? Number(diaMes) : null,
        data_especifica:
          ['DATA_ESPECIFICA', 'ANUAL'].includes(tipo) &&
          dataEspecifica
            ? dataEspecifica
            : null,
        hora_prevista: hora || null,
        prazo_minutos: prazo ? Number(prazo) : null,
        sla_minutos: sla ? Number(sla) : null,
      })

      setForm(false)
      setMensagem('Recorrência salva com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível salvar a recorrência.')
    }
  }

  async function alterar(item: Recorrencia) {
    try {
      await statusRecorrencia(item.id, !item.ativo)
      await carregar()
    } catch {
      setMensagem('Não foi possível alterar a recorrência.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Recorrências"
        descricao="Periodicidade, prazo e SLA das operações"
        usuario={usuario}
      />

      <Voltar voltar={voltar}>
        <button className="primary-button" onClick={novo}>
          + Nova recorrência
        </button>
      </Voltar>

      {form && (
        <section className="panel">
          <form className="sector-form" onSubmit={salvar}>
            <div className="form-row">
              <div className="form-group">
                <label>Operação</label>
                <select
                  value={operacaoId}
                  onChange={(e) => setOperacaoId(e.target.value)}
                  required
                >
                  <option value="">Selecione</option>
                  {operacoes
                    .filter((x) => x.ativo || x.id === operacaoId)
                    .map((x) => (
                      <option value={x.id} key={x.id}>
                        {x.nome}
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-group">
                <label>Recorrência</label>
                <select
                  value={tipo}
                  onChange={(e) => setTipo(e.target.value)}
                >
                  <option>DIARIA</option>
                  <option>SEMANAL</option>
                  <option>MENSAL</option>
                  <option>ANUAL</option>
                  <option>DATA_ESPECIFICA</option>
                  <option>SOB_DEMANDA</option>
                  <option>EVENTO</option>
                </select>
              </div>
            </div>

            {tipo === 'SEMANAL' && (
              <div className="form-group">
                <label>Dia da semana</label>
                <select
                  value={diaSemana}
                  onChange={(e) => setDiaSemana(e.target.value)}
                >
                  <option value="">Selecione</option>
                  <option value="0">Domingo</option>
                  <option value="1">Segunda-feira</option>
                  <option value="2">Terça-feira</option>
                  <option value="3">Quarta-feira</option>
                  <option value="4">Quinta-feira</option>
                  <option value="5">Sexta-feira</option>
                  <option value="6">Sábado</option>
                </select>
              </div>
            )}

            {tipo === 'MENSAL' && (
              <div className="form-group">
                <label>Dia do mês</label>
                <input
                  type="number"
                  min="1"
                  max="31"
                  value={diaMes}
                  onChange={(e) => setDiaMes(e.target.value)}
                />
              </div>
            )}

            {['DATA_ESPECIFICA', 'ANUAL'].includes(tipo) && (
              <div className="form-group">
                <label>
                  {tipo === 'ANUAL'
                    ? 'Data-base anual'
                    : 'Data específica'}
                </label>
                <input
                  type="date"
                  value={dataEspecifica}
                  onChange={(e) =>
                    setDataEspecifica(e.target.value)
                  }
                />
              </div>
            )}

            {!['SOB_DEMANDA', 'EVENTO'].includes(tipo) && (
              <div className="form-group">
                <label>Hora prevista</label>
                <input
                  type="time"
                  value={hora}
                  onChange={(e) => setHora(e.target.value)}
                />
              </div>
            )}

            <div className="form-row">
              <div className="form-group">
                <label>Prazo em minutos</label>
                <input
                  type="number"
                  min="0"
                  value={prazo}
                  onChange={(e) => setPrazo(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>SLA em minutos</label>
                <input
                  type="number"
                  min="0"
                  value={sla}
                  onChange={(e) => setSla(e.target.value)}
                />
              </div>
            </div>

            <div className="form-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => setForm(false)}
              >
                Cancelar
              </button>
              <button className="primary-button">Salvar</button>
            </div>
          </form>
        </section>
      )}

      {mensagem && <div className="system-message">{mensagem}</div>}

      <TabelaSimples
        cabecalho={[
          'Operação',
          'Recorrência',
          'Horário',
          'Prazo',
          'SLA',
          'Status',
          'Ações',
        ]}
        linhas={dados.map((item) => [
          item.operacao?.nome || '—',
          item.tipo_recorrencia.replaceAll('_', ' '),
          item.hora_prevista || '—',
          item.prazo_minutos
            ? `${item.prazo_minutos} min`
            : '—',
          item.sla_minutos ? `${item.sla_minutos} min` : '—',
          <Status ativo={item.ativo} />,
          <Acoes
            ativo={item.ativo}
            editar={() => editar(item)}
            alterar={() => alterar(item)}
          />,
        ])}
      />
    </>
  )
}

export function PerfisPage({
  usuario,
  voltar,
}: {
  usuario: DadosUsuario
  voltar: () => void
}) {
  const [usuarios, setUsuarios] = useState<any[]>([])
  const [perfis, setPerfis] = useState<any[]>([])
  const [mensagem, setMensagem] = useState('')

  async function carregar() {
    try {
      const [u, p] = await Promise.all([
        listarUsuariosEmpresa(usuario.empresaId),
        listarPerfis(),
      ])

      setUsuarios(u as any[])
      setPerfis(p as any[])
    } catch {
      setMensagem('Erro ao carregar os acessos.')
    }
  }

  useEffect(() => {
    carregar()
  }, [])

  async function alterarPerfil(
    usuarioId: string,
    perfilId: string,
    ativo: boolean
  ) {
    try {
      await atualizarAcesso(usuarioId, perfilId, ativo)
      setMensagem('Acesso atualizado com sucesso.')
      await carregar()
    } catch {
      setMensagem('Não foi possível atualizar o acesso.')
    }
  }

  return (
    <>
      <Cabecalho
        titulo="Perfis e acessos"
        descricao="Usuários já vinculados ao Supabase Auth"
        usuario={usuario}
      />

      <Voltar voltar={voltar} />

      <div className="info-box">
        Pessoas podem existir no NEXO sem possuir login. Nesta tela
        administramos apenas usuários que já possuem acesso ao sistema.
      </div>

      {mensagem && <div className="system-message">{mensagem}</div>}

      <section className="panel">
        <div className="table-wrapper">
          <table className="operations-table">
            <thead>
              <tr>
                <th>Pessoa</th>
                <th>E-mail</th>
                <th>Perfil</th>
                <th>Acesso</th>
              </tr>
            </thead>

            <tbody>
              {usuarios.map((item) => (
                <tr key={item.id}>
                  <td>
                    <strong>{item.pessoa?.nome}</strong>
                  </td>
                  <td>{item.pessoa?.email || '—'}</td>

                  <td>
                    <select
                      className="table-select"
                      value={item.perfil_id}
                      onChange={(e) =>
                        alterarPerfil(
                          item.id,
                          e.target.value,
                          item.ativo
                        )
                      }
                    >
                      {perfis.map((perfil) => (
                        <option value={perfil.id} key={perfil.id}>
                          {perfil.nome}
                        </option>
                      ))}
                    </select>
                  </td>

                  <td>
                    <button
                      className={
                        item.ativo
                          ? 'table-action-button danger'
                          : 'table-action-button success'
                      }
                      onClick={() =>
                        alterarPerfil(
                          item.id,
                          item.perfil_id,
                          !item.ativo
                        )
                      }
                    >
                      {item.ativo
                        ? 'Desativar acesso'
                        : 'Ativar acesso'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}

function Acoes({
  ativo,
  editar,
  alterar,
}: {
  ativo: boolean
  editar: () => void
  alterar: () => void
}) {
  return (
    <div className="table-actions">
      <button
        className="table-action-button"
        onClick={editar}
      >
        Editar
      </button>

      <button
        className={
          ativo
            ? 'table-action-button danger'
            : 'table-action-button success'
        }
        onClick={alterar}
      >
        {ativo ? 'Inativar' : 'Reativar'}
      </button>
    </div>
  )
}

function TabelaSimples({
  cabecalho,
  linhas,
}: {
  cabecalho: string[]
  linhas: React.ReactNode[][]
}) {
  return (
    <section className="panel">
      {linhas.length === 0 ? (
        <div className="empty-state">
          Nenhum registro encontrado.
        </div>
      ) : (
        <div className="table-wrapper">
          <table className="operations-table">
            <thead>
              <tr>
                {cabecalho.map((x) => (
                  <th key={x}>{x}</th>
                ))}
              </tr>
            </thead>

            <tbody>
              {linhas.map((linha, i) => (
                <tr key={i}>
                  {linha.map((celula, j) => (
                    <td key={j}>{celula}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}