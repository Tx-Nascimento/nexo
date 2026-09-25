import { useRef, useState } from 'react'
import { supabase } from './lib/supabase'
import Layout from './components/Layout'
import OperacoesPage from './pages/OperacoesPage'
import DemandasPage from './pages/DemandasPage'
import CentralPage from './pages/CentralPage'
import ProcessosGeralPage from './pages/ProcessosGeralPage'
import PessoasGeralPage from './pages/PessoasGeralPage'
import DocumentosPage from './pages/DocumentosPage'
import IndicadoresPage from './pages/IndicadoresPage'
import type { Pagina } from './types'
import { useUsuario } from './hooks/useUsuario'
import { podeAbrirPagina } from './lib/acesso'
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
  const { usuario, inicializando, erroAcesso, atualizarUsuario } = useUsuario()
  const [pagina, setPagina] = useState<Pagina>('central')
  const requisicaoEmAndamento = useRef(false)

  async function entrar(e: React.FormEvent) {
    e.preventDefault()
    if (requisicaoEmAndamento.current) return
    requisicaoEmAndamento.current = true
    setCarregando(true)
    setMensagem('')
    try {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password: senha })
      if (error) {
        setMensagem(error.code === 'invalid_credentials'
          ? 'E-mail ou senha inválidos.'
          : 'Não foi possível entrar. Verifique sua conexão e tente novamente.')
        return
      }
      setPagina('central')
      await atualizarUsuario()
    } catch {
      setMensagem('Não foi possível entrar. Verifique sua conexão e tente novamente.')
    } finally {
      setSenha('')
      setCarregando(false)
      requisicaoEmAndamento.current = false
    }
  }

  async function sair() {
    if (requisicaoEmAndamento.current) return
    requisicaoEmAndamento.current = true
    setCarregando(true)
    setMensagem('')
    try {
      const { error } = await supabase.auth.signOut()
      if (error) throw error
      setPagina('central')
      setEmail('')
      setSenha('')
      await atualizarUsuario()
    } catch {
      setMensagem('Não foi possível sair. Verifique sua conexão e tente novamente.')
    } finally {
      setCarregando(false)
      requisicaoEmAndamento.current = false
    }
  }

  function navegar(destino: Pagina) {
    if (usuario && podeAbrirPagina(usuario.perfil, destino)) setPagina(destino)
  }

  function renderPagina() {
    if (!usuario) return null
    if (!podeAbrirPagina(usuario.perfil, pagina)) {
      return <CentralPage usuario={usuario} navegar={navegar} />
    }
    switch (pagina) {
      case 'central': return <CentralPage usuario={usuario} navegar={navegar} />
      case 'operacoes': return <OperacoesPage usuario={usuario} />
      case 'demandas': return <DemandasPage usuario={usuario} />
      case 'processos-geral': return <ProcessosGeralPage usuario={usuario} />
      case 'pessoas-geral': return <PessoasGeralPage usuario={usuario} />
      case 'documentos': return <DocumentosPage usuario={usuario} />
      case 'indicadores': return <IndicadoresPage usuario={usuario} />
      case 'administracao': return <AdministracaoPage usuario={usuario} navegar={navegar} />
      case 'empresas': return <EmpresasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'setores': return <SetoresPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cargos': return <CargosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'pessoas': return <PessoasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'perfis': return <PerfisPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'processos': return <ProcessosPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'cadastro-operacoes': return <OperacoesCadastroPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'responsabilidades': return <ResponsabilidadesPage usuario={usuario} voltar={() => setPagina('administracao')} />
      case 'recorrencias': return <RecorrenciasPage usuario={usuario} voltar={() => setPagina('administracao')} />
      default: return <CentralPage usuario={usuario} navegar={navegar} />
    }
  }

  if (inicializando) {
    return <div className="login-page"><p role="status">Verificando seu acesso...</p></div>
  }

  if (usuario) {
    const paginaVisivel = podeAbrirPagina(usuario.perfil, pagina) ? pagina : 'central'
    return <Layout usuario={usuario} pagina={paginaVisivel} navegar={navegar} sair={sair} saindo={carregando}>
      {mensagem && <div className="system-message" role="alert">{mensagem}</div>}
      {renderPagina()}
    </Layout>
  }

  return (
    <div className="login-page"><div className="login-card"><div className="logo">NEXO</div><p className="subtitulo">Sistema Operacional da Administração</p><form onSubmit={entrar}><label>E-mail</label><input autoComplete="username" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /><label>Senha</label><input autoComplete="current-password" type="password" value={senha} onChange={(e) => setSenha(e.target.value)} required /><button type="submit" disabled={carregando}>{carregando ? 'Entrando...' : 'Entrar'}</button>{(mensagem || erroAcesso) && <div className="mensagem" role="alert">{mensagem || erroAcesso}</div>}</form></div></div>
  )
}

export default App
