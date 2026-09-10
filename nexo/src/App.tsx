import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import OperacoesPage from './pages/OperacoesPage'
import DemandasPage from './pages/DemandasPage'
import Layout from './components/Layout'
import type {
  DadosUsuario,
  Execucao,
  Pagina,
} from './types'

import {
  buscarExecucoes,
  buscarUsuarioAtual,
} from './services/nexoService'

import {
  AdministracaoPage,
  CargosPage,
  EmpresasPage,
  OperacoesCadastroPage,
  PerfisPage,
  PessoasPage,
  ProcessosPage,
  RecorrenciasPage,
  ResponsabilidadesPage,
  SetoresPage,
} from './pages/AdminPages'

import './App.css'

function App() {
  const [email, setEmail] = useState('')
  const [senha, setSenha] = useState('')
  const [mensagem, setMensagem] = useState('')
  const [carregando, setCarregando] = useState(false)

  const [usuario, setUsuario] =
    useState<DadosUsuario | null>(null)

  const [execucoes, setExecucoes] =
    useState<Execucao[]>([])

  const [pagina, setPagina] =
    useState<Pagina>('central')

  async function carregarUsuario() {
    try {
      const dados = await buscarUsuarioAtual()

      if (!dados) {
        setUsuario(null)
        return
      }

      setUsuario(dados)

      const atividades =
        await buscarExecucoes(dados.pessoaId)

      setExecucoes(atividades as Execucao[])
    } catch (error) {
      console.error(error)
      setMensagem(
        'Erro ao carregar os dados do usuário.'
      )
    }
  }

  useEffect(() => {
    carregarUsuario()
  }, [])

  async function entrar(e: React.FormEvent) {
    e.preventDefault()

    setCarregando(true)
    setMensagem('')

    const { error } =
      await supabase.auth.signInWithPassword({
        email,
        password: senha,
      })

    if (error) {
      setMensagem('E-mail ou senha inválidos.')
    } else {
      await carregarUsuario()
    }

    setCarregando(false)
  }

  async function sair() {
    await supabase.auth.signOut()

    setUsuario(null)
    setExecucoes([])
    setPagina('central')
    setEmail('')
    setSenha('')
    setMensagem('')
  }

  function atrasada(execucao: Execucao) {
    if (!execucao.data_prevista) return false

    return (
      new Date(execucao.data_prevista) < new Date()
    )
  }

  function TelaCentral() {
    const total = execucoes.length
    const atrasadas =
      execucoes.filter(atrasada).length

    const bloqueadas = execucoes.filter(
      (x) => x.status === 'BLOQUEADA'
    ).length

    const aguardando = execucoes.filter((x) =>
      [
        'AGUARDANDO_INFORMACAO',
        'AGUARDANDO_TERCEIRO',
        'AGUARDANDO_CONFERENCIA',
        'AGUARDANDO_APROVACAO',
      ].includes(x.status)
    ).length

    return (
      <>
        <header className="topbar">
          <div>
            <h1>Minha Central</h1>
            <p>
              Visão operacional das suas responsabilidades
            </p>
          </div>

          <div className="topbar-user">
            {usuario?.nome}
          </div>
        </header>

        <section className="welcome">
          <h2>Olá, {usuario?.nome}</h2>

          <p>
            Aqui você acompanha atividades,
            prioridades, bloqueios e pendências que
            exigem sua ação.
          </p>
        </section>

        <section className="cards-grid">
          <Card titulo="Minhas atividades" valor={total} />
          <Card titulo="Atrasadas" valor={atrasadas} />
          <Card titulo="Bloqueadas" valor={bloqueadas} />
          <Card titulo="Aguardando" valor={aguardando} />
        </section>

        <section className="panel">
          <div className="panel-header">
            <h3>Prioridades</h3>
            <p>
              Atividades sob sua responsabilidade.
            </p>
          </div>

          {execucoes.length === 0 ? (
            <div className="empty-state">
              Nenhuma execução pendente.
            </div>
          ) : (
            <div className="table-wrapper">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Atividade</th>
                    <th>Prioridade</th>
                    <th>Status</th>
                    <th>Prazo</th>
                    <th>Progresso</th>
                  </tr>
                </thead>

                <tbody>
                  {execucoes.map((item) => (
                    <tr key={item.id}>
                      <td>
                        <strong>{item.titulo}</strong>
                      </td>

                      <td>{item.prioridade}</td>

                      <td>
                        {item.status.replaceAll('_', ' ')}
                      </td>

                      <td>
                        {item.data_prevista
                          ? new Date(
                              item.data_prevista
                            ).toLocaleString('pt-BR')
                          : 'Sem prazo'}
                      </td>

                      <td>
                        {item.percentual_conclusao}%
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </>
    )
  }

  function TelaBase({
    titulo,
    descricao,
  }: {
    titulo: string
    descricao: string
  }) {
    return (
      <>
        <header className="topbar">
          <div>
            <h1>{titulo}</h1>
            <p>{descricao}</p>
          </div>

          <div className="topbar-user">
            {usuario?.nome}
          </div>
        </header>

        <section className="panel">
          <div className="empty-state">
            Módulo preparado para a próxima etapa
            operacional.
          </div>
        </section>
      </>
    )
  }

  function renderPagina() {
    if (!usuario) return null

    switch (pagina) {
      case 'central':
        return <TelaCentral />

      case 'administracao':
        return (
          <AdministracaoPage
            usuario={usuario}
            navegar={setPagina}
          />
        )

      case 'empresas':
        return (
          <EmpresasPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'setores':
        return (
          <SetoresPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'cargos':
        return (
          <CargosPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'pessoas':
        return (
          <PessoasPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'perfis':
        return (
          <PerfisPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'processos':
        return (
          <ProcessosPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'cadastro-operacoes':
        return (
          <OperacoesCadastroPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'responsabilidades':
        return (
          <ResponsabilidadesPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'recorrencias':
        return (
          <RecorrenciasPage
            usuario={usuario}
            voltar={() =>
              setPagina('administracao')
            }
          />
        )

      case 'operacoes':
        return <OperacoesPage usuario={usuario} /> 
      
      case 'demandas':
        return <DemandasPage usuario={usuario} />
       
      case 'processos-geral':
        return (
          <TelaBase
            titulo="Processos"
            descricao="Visão operacional dos processos"
          />
        )

      case 'pessoas-geral':
        return (
          <TelaBase
            titulo="Pessoas"
            descricao="Responsabilidades, carga e atuação das pessoas"
          />
        )

      case 'documentos':
        return (
          <TelaBase
            titulo="Documentos"
            descricao="Procedimentos, arquivos, modelos e evidências"
          />
        )

      case 'indicadores':
        return (
          <TelaBase
            titulo="Indicadores"
            descricao="Desempenho, prazo, qualidade e produtividade"
          />
        )
    }
  }

  if (usuario) {
    return (
      <Layout
        usuario={usuario}
        pagina={pagina}
        navegar={setPagina}
        sair={sair}
      >
        {renderPagina()}
      </Layout>
    )
  }

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="logo">NEXO</div>

        <p className="subtitulo">
          Sistema Operacional da Administração
        </p>

        <form onSubmit={entrar}>
          <label>E-mail</label>

          <input
            type="email"
            value={email}
            onChange={(e) =>
              setEmail(e.target.value)
            }
            required
          />

          <label>Senha</label>

          <input
            type="password"
            value={senha}
            onChange={(e) =>
              setSenha(e.target.value)
            }
            required
          />

          <button
            type="submit"
            disabled={carregando}
          >
            {carregando
              ? 'Entrando...'
              : 'Entrar'}
          </button>

          {mensagem && (
            <div className="mensagem">
              {mensagem}
            </div>
          )}
        </form>
      </div>
    </div>
  )
}

function Card({
  titulo,
  valor,
}: {
  titulo: string
  valor: number
}) {
  return (
    <div className="status-card">
      <span className="card-label">{titulo}</span>
      <strong className="card-value">{valor}</strong>
    </div>
  )
}

export default App