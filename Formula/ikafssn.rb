class Ikafssn < Formula
  desc "K-mer-based alignment-free similarity search for nucleotide sequences"
  homepage "https://github.com/astanabe/ikafssn"
  url "https://github.com/astanabe/ikafssn/archive/refs/tags/v0.1.2026.04.30.tar.gz"
  sha256 "fff4fb44bbf12d2c9a48528588f3b36f35103b48c96ff23fd14c382172faaa67"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/astanabe/ikafssn/releases/download/v0.1.2026.04.30"
    sha256 cellar: :any, arm64_tahoe: "3ac608967dd03fb43607e34983892a0569dc6faee6591cd2568bfe40a15589cf"
  end

  depends_on "cmake" => :build
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "curl"
  depends_on "jsoncpp"
  depends_on "libdeflate"
  depends_on "lmdb"
  depends_on "openssl@3"
  depends_on "sqlite"
  depends_on "tbb"
  depends_on "xz"

  resource "ncbi-cxx-toolkit" do
    url "https://github.com/ncbi/ncbi-cxx-toolkit-public/archive/refs/tags/release/30.2.0.tar.gz"
    sha256 "17294b30dfbdef7bc4fc3785e2b6e43e7166c61a22df22874ff28e2876de50ec"
  end

  resource "parasail" do
    url "https://github.com/jeffdaily/parasail/archive/refs/tags/v2.6.2.tar.gz"
    sha256 "9057041db8e1cde76678f649420b85054650414e5de9ea84ee268756c7ea4b4b"
  end

  resource "htslib" do
    url "https://github.com/samtools/htslib/releases/download/1.23.1/htslib-1.23.1.tar.bz2"
    sha256 "f8a3f36effeec38f043c53ab1f2d9ed45064f14205c5ef8e3c815763b90803c4"
  end

  resource "drogon" do
    url "https://github.com/drogonframework/drogon/archive/refs/tags/v1.9.12.tar.gz"
    sha256 "becc3c4f3b90f069f814baef164a7e3a2b31476dc6fe249b02ff07a13d032f48"
  end

  # The Drogon release tarball does not include the trantor submodule contents;
  # this is the matching trantor release tag (commit 5000e2a).
  resource "trantor" do
    url "https://github.com/an-tao/trantor/archive/refs/tags/v1.5.26.tar.gz"
    sha256 "e47092938aaf53d51c8bc72d8f54ebdcf537e6e4ac9c8276f3539413d6dfeddf"
  end

  def install
    # Build Parasail (static, patched for DEGMATCH matrix and score-based CIGAR match)
    resource("parasail").stage do
      system "patch", "-p1", "-i", "#{buildpath}/patches/parasail-degmatch-cigar-score.patch"
      system "cmake", "-S", ".", "-B", "build",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/parasail",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
      system "cmake", "--install", "build"
    end

    # Build htslib (static)
    resource("htslib").stage do
      system "autoreconf", "-i"
      system "./configure",
             "--prefix=#{buildpath}/htslib",
             "--disable-libcurl", "--disable-gcs", "--disable-s3",
             "CPPFLAGS=-I#{HOMEBREW_PREFIX}/include",
             "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib"
      system "make", "-j#{ENV.make_jobs}"
      system "make", "install"
    end

    # Build NCBI C++ Toolkit (static, patched for madvise MADV_RANDOM on SeqDB mmaps)
    resource("ncbi-cxx-toolkit").stage do
      system "patch", "-p1", "-i", "#{buildpath}/patches/ncbi-cxx-toolkit-seqdb-madvise-random.patch"
      ENV.prepend "CFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      ENV.prepend "CXXFLAGS", "-I#{HOMEBREW_PREFIX}/include"
      system "./cmake-configure",
             "--without-debug",
             "--with-projects=objtools/blast/seqdb_reader;objtools/blast/blastdb_format",
             "--with-install=#{buildpath}/ncbi-cxx-toolkit"
      cd Dir["CMake-*/build"].first do
        system "make", "-j#{ENV.make_jobs}"
        system "make", "install"
      end
    end

    # Detect NCBI build tag
    ncbi_build_tag = Dir["#{buildpath}/ncbi-cxx-toolkit/CMake-*/"].map { |d| File.basename(d) }.first

    # Build Drogon (static; trantor submodule replaced by the matching release tarball)
    resource("drogon").stage do
      drogon_src = Pathname.pwd
      rm_r drogon_src/"trantor"
      (drogon_src/"trantor").mkpath
      resource("trantor").stage(drogon_src/"trantor")

      system "cmake", "-S", ".", "-B", "build",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DCMAKE_INSTALL_PREFIX=#{buildpath}/drogon",
             "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}",
             "-DBUILD_SHARED_LIBS=OFF",
             "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
             "-DBUILD_CTL=OFF",
             "-DBUILD_EXAMPLES=OFF",
             "-DBUILD_ORM=OFF",
             "-DBUILD_BROTLI=OFF",
             "-DBUILD_YAML_CONFIG=OFF",
             "-DBUILD_DOC=OFF"
      system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
      system "cmake", "--install", "build"
    end

    # Build ikafssn
    system "cmake", "-S", ".", "-B", "build",
           "-DCMAKE_BUILD_TYPE=Release",
           "-DNCBI_TOOLKIT_BUILD_TAG=#{ncbi_build_tag}",
           "-DDROGON_DIR=#{buildpath}/drogon",
           "-DBUILD_HTTPD=ON",
           *std_cmake_args
    system "cmake", "--build", "build", "-j#{ENV.make_jobs}"
    system "cmake", "--install", "build"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ikafssnindex --version 2>&1")
  end
end
