import { useEffect, useState } from 'react'
import { supabase } from './lib/supabase'
import Layout from './components/Layout'
import OperacoesPage from './pages/OperacoesPage'
import DemandasPage from './pages/DemandasPage'
import CentralPage from './pages/CentralPage'
import ProcessosGeralPage from './pages/ProcessosGeralPage'
import PessoasGeralPage from './pages/PessoasGeralPage'
import DocumentosPage from './pages/DocumentosPage'
import IndicadoresPage from './pages/IndicadoresPage'
import type { DadosUsuario, Pagina } from './types'
import { buscarUsuarioAtual } from './services/nexoService'
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
  const [usuario, setUsuario] = useState<DadosUsuario | null>(null)
  const [pagina, setPagina] = useState<Pagina>('central')

  async function carregarUsuario() {
    try {
      const dados = await buscarUsuarioAtual()
      setUsuario(dados)
    } catch (error) {
      console.error(error)
      setMensagem('Erro ao carregar os dados do usuário.')
    }
  }

  useEffect(() => { carregarUsuario() }, [])

  async function entrar(e: React.FormEvent) {
    e.preventDefault()
    setCarregando(true)
    setMensagem('')
    const { error } = await supabase.auth.signInWithPassword({ email, password: senha })
    if (error) setMensagem('E-mail ou senha inválidos.')
    else await carregarUsuario()
    setCarregando(false)
  }

  async function sair() {
    await supabase.auth.signOut()
    setUsuario(null)
    setPagina('central')
    setEmail('')
    setSenha('')
    setMensagem('')
  }

  function renderPagina() {
    if (!usuario) return null
    switch (pagina) {
      case 'central': return <CentralPage usuario={usuario} navegar={setPagina} />
      case 'operacoes': return <OperacoesPage usuario={usuario} />
      case 'demandas': return <DemandasPage usuario={usuario} />
      case 'processos-geral': return <ProcessosGeralPage usuario={usuario} />
      case 'pessoas-geral': return <PessoasGeralPage usuario={usuario} />
      case 'documentos': return <DocumentosPage usuario={usuario} />
      case 'indicadores': return <IndicadoresPage usuario={usuario} />
      case 'administracao': return <AdministracaoPage usuario={usuario} navegar={setPagina} />
      case 'empresas': return <EmpresasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'setores': return <SetoresPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cargos': return <CargosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'pessoas': return <PessoasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'perfis': return <PerfisPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'processos': return <ProcessosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cadastro-operacoes': return <OperacoesCadastroPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'responsabilidades': return <ResponsabilidadesPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'recorrencias': return <RecorrenciasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      default: return <CentralPage usuario={usuario} navegar={setPagina} />
    }
  }

  if (usuario) {
    return <Layout usuario={usuario} pagina={pagina} navegar={setPagina} sair={sair}>{renderPagina()}</Layout>
  }

  return (
    <div className="login-page"><div className="login-card"><div className="logo">NEXO</div><p className="subtitulo">Sistema Operacional da Administração</p><form onSubmit={entrar}><label>E-mail</label><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /><label>Senha</label><input type="password" value={senha} onChange={(e) => setSenha(e.target.value)} required /><button type="submit" disabled={carregando}>{carregando ? 'Entrando...' : 'Entrar'}</button>{mensagem && <div className="mensagem">{mensagem}</div>}</form></div></div>
  )
}

export default App
