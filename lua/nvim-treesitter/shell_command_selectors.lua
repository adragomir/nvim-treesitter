local fn = vim.fn
local utils = require'nvim-treesitter.utils'
local configs = require'nvim-treesitter.configs'

local M = {}

function M.select_mkdir_cmd(directory, cwd, info_msg)
  if fn.has('win32') == 1 and not configs.force_unix_shell then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'mkdir', directory},
        cwd = cwd,
      },
      info = info_msg,
      err = "Could not create "..directory,
    }
  else
    return {
      cmd = 'mkdir',
      opts = {
        args = { directory },
        cwd = cwd,
      },
      info = info_msg,
      err = "Could not create "..directory,
    }
  end
end

function M.select_rm_file_cmd(file, info_msg)
  if fn.has('win32') == 1 and not configs.force_unix_shell then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'if', 'exist', file, 'del', file },
      },
      info = info_msg,
      err = "Could not delete "..file,
    }
  else
    return {
      cmd = 'rm',
      opts = {
        args = { file },
      },
      info = info_msg,
      err = "Could not delete "..file,
    }
  end
end

function M.select_executable(executables)
  return vim.tbl_filter(function(c) return c ~= vim.NIL and fn.executable(c) == 1 end, executables)[1]
end

function M.select_compiler_args(repo, compiler)
  if (string.match(compiler, 'cl$') or string.match(compiler, 'cl.exe$')) then
    return {
      '/Fe:',
      'parser.so',
      '/Isrc',
      repo.files,
      '-Os',
      '/LD',
    }
  else
    local args = {
      '-o',
      'parser.so',
      '-I./src',
      repo.files,
      '-shared',
      '-Os',
      '-lstdc++',
    }
    if fn.has('win32') == 0 or configs.force_unix_shell == true then
     table.insert(args, '-fPIC')
    end
    return args
  end
end

function M.select_install_rm_cmd(cache_folder, project_name)
  if fn.has('win32') == 1 and not configs.force_unix_shell then
    local dir = cache_folder ..'\\'.. project_name
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'if', 'exist', dir, 'rmdir', '/s', '/q', dir },
      }
    }
  else
    return {
      cmd = 'rm',
      opts = {
        args = { '-rf', cache_folder..'/'..project_name },
      }
    }
  end
end

function M.select_mv_cmd(from, to, cwd)
  if fn.has('win32') == 1 and not configs.force_unix_shell then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'move', '/Y', from, to },
        cwd = cwd,
      }
    }
  else
    return {
      cmd = 'mv',
      opts = {
        args = { from, to },
        cwd = cwd,
      },
    }
  end
end

function M.select_download_commands(repo, project_name, cache_folder, revision)

  local is_github = repo.url:find("github.com", 1, true)
  local is_gitlab = repo.url:find("gitlab.com", 1, true)

  if vim.fn.executable('tar') == 1 and vim.fn.executable('curl') == 1 and (is_github or is_gitlab) then

    revision = revision or repo.branch or "master"
    local path_sep = utils.get_path_sep()
    local url = repo.url:gsub('.git$', '')

    return {
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp'),
      {
        cmd = 'curl',
        info = 'Downloading...',
        err = 'Error during download, please verify your internet connection',
        opts = {
          args = {
            '-L', -- follow redirects
            is_github and url.."/archive/"..revision..".tar.gz"
                      or url.."/-/archive/"..revision.."/"..project_name.."-"..revision..".tar.gz",
            '--output',
            project_name..".tar.gz"
          },
          cwd = cache_folder,
        },
      },
      M.select_mkdir_cmd(project_name..'-tmp', cache_folder, 'Creating temporary directory'),
      {
        cmd = 'tar',
        info = 'Extracting...',
        err = 'Error during tarball extraction.',
        opts = {
          args = {
            '-xvf',
            project_name..".tar.gz",
            '-C',
            project_name..'-tmp',
          },
          cwd = cache_folder,
        },
      },
      M.select_rm_file_cmd(cache_folder..path_sep..project_name..".tar.gz"),
      M.select_mv_cmd(utils.join_path(project_name..'-tmp', url:match('[^/]-$')..'-'..revision),
        project_name,
        cache_folder),
      M.select_install_rm_cmd(cache_folder, project_name..'-tmp')
    }
  else
    return {
      {
        cmd = 'git',
        info = 'Downloading...',
        err = 'Error during download, please verify your internet connection',
        opts = {
          args = {
            'clone',
            '--single-branch',
            '--branch', repo.branch or 'master',
            '--depth', '1',
            repo.url,
            project_name
          },
          cwd = cache_folder,
        },
      }
    }
  end
end

function M.make_directory_change_for_command(dir, command)
  if fn.has('win32') == 1 and not configs.force_unix_shell then
    return string.format("pushd %s & %s & popd", dir, command)
  else
    return string.format("cd %s;\n %s", dir, command)
  end
end

return M
